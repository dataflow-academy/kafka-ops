"""Scripts call each other by path: every script and manifest they name has to exist (folders get removed)."""
from pathlib import Path
import re
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
# "$ROOT/cluster/prepare.sh", "$HERE/fixes/skip-poison-pill.sh" (HERE is the folder of the script)
REFERENCE = re.compile(r'"\$(ROOT|HERE)/([A-Za-z0-9_./-]+\.(?:sh|yaml|py))"')


class ScriptReferences(unittest.TestCase):
    def test_referenced_scripts_exist(self):
        scripts = [p for p in ROOT.rglob('*.sh') if '.git' not in p.parts]
        self.assertTrue(scripts)
        for script in scripts:
            for base, path in REFERENCE.findall(script.read_text()):
                with self.subTest(script=str(script.relative_to(ROOT)), path=path):
                    folder = ROOT if base == 'ROOT' else script.parent
                    self.assertTrue((folder / path).exists() or (ROOT / path).exists())

    def test_the_new_alerts_topic_is_the_one_of_the_healthy_wind_park(self):
        new = yaml.safe_load((ROOT / 'windpark/alerts-topic.yaml').read_text())
        healthy = [d for d in yaml.safe_load_all((ROOT / 'windpark/windpark-healthy.yaml').read_text())
                   if d and d['kind'] == 'KafkaTopic' and d['metadata']['name'] == new['metadata']['name']]
        self.assertEqual(len(healthy), 1)
        self.assertEqual(new['spec'], healthy[0]['spec'])
        self.assertEqual(new['spec']['replicas'], 3)


if __name__ == '__main__':
    unittest.main()
