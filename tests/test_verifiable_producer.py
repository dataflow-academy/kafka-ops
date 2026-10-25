"""The verifiable producer takes acks as Kafka names them and is idempotent only with acks=all."""
import importlib.util
from pathlib import Path
import sys
import types
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]


class FakeProducer:
    configs = []

    def __init__(self, conf):
        FakeProducer.configs.append(conf)

    def produce(self, *args, **kwargs):
        pass

    def poll(self, timeout):
        return 0

    def flush(self, timeout=None):
        return 0


def load():
    sys.modules['confluent_kafka'] = types.SimpleNamespace(Producer=FakeProducer)
    spec = importlib.util.spec_from_file_location('verifiable_producer', ROOT / 'tools/verifiable-producer.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class VerifiableProducerTest(unittest.TestCase):
    def config_for(self, acks):
        module = load()
        argv = ['verifiable-producer.py', '--bootstrap-server', 'x:1', '--topic', 't', '--max-messages', '0', '--acks', acks]
        with mock.patch.object(sys, 'argv', argv), self.assertRaises(SystemExit):
            module.main()
        return FakeProducer.configs[-1]

    def test_all_and_minus_one_are_idempotent(self):
        for acks in ('all', '-1'):
            with self.subTest(acks=acks):
                conf = self.config_for(acks)
                self.assertEqual(conf['acks'], 'all')
                self.assertTrue(conf['enable.idempotence'])
                self.assertGreaterEqual(conf['retries'], 1)

    def test_one_and_zero_are_not_idempotent(self):
        for acks in ('1', '0'):
            with self.subTest(acks=acks):
                conf = self.config_for(acks)
                self.assertEqual(conf['acks'], acks)
                self.assertNotIn('enable.idempotence', conf)

    def test_unknown_acks_are_rejected(self):
        module = load()
        with mock.patch.object(sys, 'argv', ['p', '--bootstrap-server', 'x:1', '--topic', 't', '--acks', '2']), \
                mock.patch('sys.stderr'), self.assertRaises(SystemExit) as raised:
            module.main()
        self.assertEqual(raised.exception.code, 2)


if __name__ == '__main__':
    unittest.main()
