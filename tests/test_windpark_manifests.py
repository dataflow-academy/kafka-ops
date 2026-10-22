"""Checks the two wind park manifests without a cluster: they parse, the images are pinned, the files differ only in the faults."""
from pathlib import Path
import re
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
WINDPARK = ROOT / 'windpark'
GHCR_PREFIX = 'ghcr.io/dataflow-academy/'
STRIMZI_IMAGE = re.compile(r'^quay\.io/strimzi/kafka:\d+\.\d+\.\d+-kafka-\d+\.\d+\.\d+$')
GHCR_IMAGE = re.compile('^' + re.escape(GHCR_PREFIX) + r'[a-z0-9/-]+:[0-9a-f]{40}$')

# Everything that may differ between the training state and the healthy state: (kind, name, path).
FAULT_FIELDS = {
    ('ConfigMap', 'scada-config', 'data.KAFKA_ACKS'),                                # F5
    ('ConfigMap', 'scada-config', 'data.KAFKA_ENABLE_IDEMPOTENCE'),                  # F5
    ('ConfigMap', 'abrechnung-config', 'data.TOPIC'),                                # F1
    ('ConfigMap', 'wartung-config', 'data.POWER_KW'),                                # F2
    ('ConfigMap', 'alarme-config', 'data.TOPIC'),                                    # F3
    ('Deployment', 'prognose', 'spec.template.spec.containers.0.resources.requests.cpu'),   # F4
    ('Deployment', 'prognose', 'spec.template.spec.containers.0.resources.limits.cpu'),     # F4
    ('KafkaTopic', 'windpark-alerts', ''),                                           # F3, only in windpark.yaml
    ('KafkaTopic', 'nordwind.alarme.public.windpark-alert.event', ''),               # F3, only in the healthy file
}


def documents(path):
    return [d for d in yaml.safe_load_all(path.read_text()) if d]


def by_name(path):
    return {(d['kind'], d['metadata']['name']): d for d in documents(path)}


def leaves(node, prefix=''):
    if isinstance(node, dict):
        for key, value in node.items():
            yield from leaves(value, f'{prefix}.{key}' if prefix else str(key))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            yield from leaves(value, f'{prefix}.{index}' if prefix else str(index))
    else:
        yield prefix, node


class WindparkManifests(unittest.TestCase):
    files = ('windpark.yaml', 'windpark-healthy.yaml')

    def test_files_parse_and_are_complete(self):
        for name in self.files:
            with self.subTest(name):
                docs = documents(WINDPARK / name)
                kinds = [d['kind'] for d in docs]
                self.assertEqual(kinds.count('Namespace'), 1)
                self.assertEqual(kinds.count('CronJob'), 1)
                self.assertEqual(kinds.count('Deployment'), 6)
                self.assertEqual(kinds.count('ConfigMap'), 7)
                for d in docs:
                    if d['kind'] != 'Namespace':
                        self.assertIn(d['metadata']['namespace'], ('windpark', 'kafka'), d['metadata']['name'])
                    if d['kind'] == 'ConfigMap':
                        self.assertRegex(d['metadata']['name'], r'^[a-z]+-config$')

    def test_config_maps_referenced_by_workloads_exist(self):
        for name in self.files:
            with self.subTest(name):
                docs = by_name(WINDPARK / name)
                for (kind, workload), d in docs.items():
                    if kind not in ('Deployment', 'CronJob'):
                        continue
                    text = yaml.dump(d)
                    for ref in re.findall(r'configMapRef:\s+name: (\S+)', text):
                        self.assertIn(('ConfigMap', ref), docs, f'{workload} uses {ref}')

    def test_images_are_pinned(self):
        for name in self.files:
            with self.subTest(name):
                images = [v for d in documents(WINDPARK / name) for p, v in leaves(d) if p.endswith('.image')]
                self.assertEqual(len(images), 7)
                for image in images:
                    self.assertTrue(GHCR_IMAGE.match(image) or STRIMZI_IMAGE.match(image), image)

    def test_files_differ_only_in_the_faults(self):
        training, healthy = by_name(WINDPARK / 'windpark.yaml'), by_name(WINDPARK / 'windpark-healthy.yaml')
        differences = set()
        for key in set(training) | set(healthy):
            if key not in training or key not in healthy:
                differences.add((*key, ''))
                continue
            a, b = dict(leaves(training[key])), dict(leaves(healthy[key]))
            differences |= {(*key, path) for path in set(a) | set(b) if a.get(path) != b.get(path)}
        self.assertEqual(differences, FAULT_FIELDS)

    def test_topic_variants_parse(self):
        for variant in ('sensible', 'as-requested'):
            with self.subTest(variant):
                files = sorted((WINDPARK / 'topics' / variant).glob('*.yaml'))
                self.assertEqual([f.name for f in files], ['park-registry.yaml', 'telemetry.yaml', 'turbine-registry.yaml'])
                for f in files:
                    self.assertEqual([d['kind'] for d in documents(f)], ['KafkaTopic'])


if __name__ == '__main__':
    unittest.main()
