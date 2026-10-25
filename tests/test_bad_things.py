"""Exercise entry points must select one fixed incident and propagate injection failures."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BadThingsTest(unittest.TestCase):
    def run_incident(self, number, status):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            entry = target / f'bad-things{number}.sh'
            shutil.copyfile(ROOT / 'chaos' / entry.name, entry)
            breaker = target / 'break.sh'
            breaker.write_text('#!/bin/sh\nprintf "%s" "$1" > "$HOME/selected"\nexit "$INJECTION_STATUS"\n')
            breaker.chmod(0o755)
            env = dict(os.environ, HOME=directory, INJECTION_STATUS=str(status))
            result = subprocess.run(['bash', str(entry)], env=env, capture_output=True, text=True)
            return result, (target / 'selected').read_text(), (target / f'.bad-things{number}-started').exists()

    def test_numbered_incidents_are_deterministic(self):
        for number, failure in [(1, 'P1'), (2, 'P4'), (3, 'P5')]:
            with self.subTest(number=number):
                result, selected, marker = self.run_incident(number, 0)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(selected, failure)
                self.assertTrue(marker)
                self.assertNotIn(failure, result.stdout)

    def test_rescue_skeleton_is_editable_yaml_with_a_pinned_image(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(['bash', str(ROOT / 'chaos/rescue-skeleton.sh')],
                                    env=dict(os.environ, HOME=directory), text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            text = (Path(directory) / 'rescue.yaml').read_text()
            self.assertIn('claimName: data-0-my-cluster-broker-N', text)
            self.assertIn('image: rancher/mirrored-library-busybox:1.37.0', text)
            self.assertNotIn('${BUSYBOX_VERSION}', text)

    def test_failed_injection_is_not_marked_as_started(self):
        for number in (1, 2, 3):
            with self.subTest(number=number):
                result, _, marker = self.run_incident(number, 42)
                self.assertEqual(result.returncode, 42)
                self.assertFalse(marker)


if __name__ == '__main__':
    unittest.main()
