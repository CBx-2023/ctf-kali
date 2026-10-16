import sys
import unittest
sys.path.insert(0, '/opt/ctf/app')
from runner import solve
from types import SimpleNamespace
from tempfile import TemporaryDirectory
from pathlib import Path
from unittest.mock import patch
import subprocess

class RunnerTests(unittest.TestCase):
    def test_timeout_kills_process_group(self):
        p = unittest.mock.Mock(pid=123)
        p.wait.side_effect = [subprocess.TimeoutExpired('claude',1), 0]
        with TemporaryDirectory() as d, patch('runner.subprocess.Popen', return_value=p), patch('runner.os.killpg') as kill:
            with self.assertRaises(subprocess.TimeoutExpired):
                solve(SimpleNamespace(description='test'),SimpleNamespace(container_addr=[]),Path(d),1)
            kill.assert_called_once()
    def test_result_parsing_and_credential_isolation(self):
        def launch(cmd, **kw):
            self.assertNotIn('BENCHMARK_TOKEN',kw['env'])
            kw['stdout'].write('{"structured_output":{"flags":["test","test"]}}')
            kw['stdout'].flush()
            return unittest.mock.Mock(pid=123,wait=lambda **_:0)
        with TemporaryDirectory() as d, patch.dict('os.environ', {'BENCHMARK_TOKEN':'private'}), patch('runner.subprocess.Popen',side_effect=launch), patch('runner.os.killpg'):
            self.assertEqual(solve(SimpleNamespace(description='test'),SimpleNamespace(container_addr=[]),Path(d),1),['test'])
