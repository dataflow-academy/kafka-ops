"""Exercise entry points must select one fixed incident, and the incidents of the lab must be marked as started."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
# The fake break.sh records the failure it was asked for and whether the marker existed already.
FAKE_BREAK = '#!/bin/sh\nprintf "%s %s" "$1" "$(ls -A "$HOME" | grep -c started)" > "$HOME/selected"\nexit "$INJECTION_STATUS"\n'


class BadThingsTest(unittest.TestCase):
    def run_incident(self, number, status):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            entry = target / f'bad-things{number}.sh'
            shutil.copyfile(ROOT / 'chaos' / entry.name, entry)
            breaker = target / 'break.sh'
            breaker.write_text(FAKE_BREAK)
            breaker.chmod(0o755)
            env = dict(os.environ, HOME=directory, INJECTION_STATUS=str(status))
            result = subprocess.run(['bash', str(entry)], env=env, capture_output=True, text=True)
            selected, marked_before = (target / 'selected').read_text().split()
            return result, selected, marked_before == '1', (target / f'.bad-things{number}-started').exists()

    def test_numbered_incidents_are_deterministic(self):
        for number, failure in [('1', 'P1'), ('1b', 'P1b'), ('2', 'P4')]:
            with self.subTest(number=number):
                result, selected, _, marker = self.run_incident(number, 0)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(selected, failure)
                self.assertTrue(marker)
                self.assertNotIn(failure, result.stdout)

    def test_the_incidents_are_marked_before_they_start(self):
        for number in ('1', '2'):
            with self.subTest(number=number):
                result, _, marked_before, marker = self.run_incident(number, 42)
                self.assertEqual(result.returncode, 42)
                self.assertTrue(marked_before)
                self.assertTrue(marker)

    def test_a_refused_second_broker_is_not_marked(self):
        result, _, marked_before, marker = self.run_incident('1b', 42)
        self.assertEqual(result.returncode, 42)
        self.assertFalse(marked_before)
        self.assertFalse(marker)

    def test_rescue_pod_is_editable_yaml_with_a_pinned_image(self):
        text = (ROOT / 'chaos/rescue-pod.yaml').read_text()
        self.assertIn('claimName: data-0-nordwind-kafka-broker-N', text)
        self.assertIn('image: rancher/mirrored-library-busybox:1.37.0', text)
        self.assertNotIn('${', text)

    def test_the_experiment_topics_use_the_broker_defaults(self):
        text = (ROOT / 'chaos/topics.yaml').read_text()
        for name in ('chaos-acks-all', 'chaos-acks-1', 'chaos-acks-0'):
            self.assertIn(f'name: {name}\n', text)
        self.assertNotIn('config:', text)
        self.assertNotIn('TODO', text)


if __name__ == '__main__':
    unittest.main()
