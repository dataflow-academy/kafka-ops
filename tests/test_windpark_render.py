"""Render the participant manifests without a cluster or any mutating kubectl command."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class WindparkRenderTest(unittest.TestCase):
    def render(self, *args):
        with tempfile.TemporaryDirectory() as directory:
            wrapper = Path(directory) / 'kubectl'
            wrapper.write_text('#!/bin/sh\n[ "$1" = kustomize ] || exit 91\nexec "$REAL_KUBECTL" "$@"\n')
            wrapper.chmod(0o755)
            env = dict(os.environ, WIND_IMAGE_REGISTRY='registry.example.test/training',
                       REAL_KUBECTL=shutil.which('kubectl'),
                       PATH=directory + os.pathsep + os.environ['PATH'])
            return subprocess.run(['bash', str(ROOT / 'windpark/render.sh'), *args],
                                  env=env, text=True, capture_output=True)

    def test_training_keeps_faults_and_resolves_images(self):
        result = self.render()
        self.assertEqual(result.returncode, 0, result.stderr)
        text = result.stdout
        self.assertIn('TOPIC: telemetery', text)
        self.assertIn('POWER_KW: n/a', text)
        self.assertIn('cpu: 25m', text)
        self.assertIn('KAFKA_ACKS: "1"', text)
        self.assertIn('topicName: windpark_alerts', text)
        self.assertIn('registry.example.test/training/java/wind-turbine-producer-json:', text)
        self.assertNotIn('${WIND_', text)
        self.assertNotIn('${STRIMZI_', text)
        self.assertNotIn('${KAFKA_VERSION}', text)
        self.assertIn('${TURBINE%-*}', text)
        self.assertIn('$POWER_KW', text)
        for document in text.split('\n---\n'):
            if 'kind: Namespace' not in document:
                self.assertRegex(document, r'\n  namespace: (windpark|kafka)(?:\n|$)')

    def test_healthy_mode_has_no_training_faults(self):
        result = self.render('healthy')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('TOPIC: telemetery', result.stdout)
        self.assertNotIn('POWER_KW: n/a', result.stdout)
        self.assertNotIn('cpu: 25m', result.stdout)
        self.assertNotIn('topicName: windpark_alerts', result.stdout)
        self.assertIn('KAFKA_ACKS: all', result.stdout)
        self.assertIn('POWER_KW: "0.0"', result.stdout)

    def test_invalid_mode_fails_without_partial_manifests(self):
        result = self.render('missing-overlay')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')


if __name__ == '__main__':
    unittest.main()
