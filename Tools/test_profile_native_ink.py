"""Profiler infrastructure must not replace the original test's real outcome."""
import contextlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import profile_native_ink


class OriginalOutcomeTests(unittest.TestCase):
    def test_profiler_targets_the_selected_simulator_not_the_host(self):
        # Native xctrace's host default cannot resolve a simulator-only PID.
        # Exercise the real process invocation against a minimal external CLI
        # contract; this test is not evidence of an actual GPU capture.
        with tempfile.TemporaryDirectory() as temporary:
            previous = Path.cwd()
            try:
                os.chdir(temporary)
                binary = Path('xcrun')
                binary.write_text('#!' + sys.executable + '\nimport sys,pathlib,json\na=sys.argv[1:]\npathlib.Path("trace-argv.json").write_text(json.dumps(a))\nif "--device" not in a or a[a.index("--device")+1]!="test-device": raise SystemExit(21)\npathlib.Path(a[a.index("--output")+1]).mkdir()\n')
                binary.chmod(0o755)
                with patch.dict(os.environ, {"PATH": str(Path.cwd()) + os.pathsep + os.environ['PATH'],
                     "GITHUB_SHA": "test-source", "GITHUB_RUN_ID": "1", "SIMULATOR_ID": "test-device"}), \
                     patch.object(profile_native_ink, 'actual_app_pid', return_value=123), \
                     contextlib.redirect_stdout(io.StringIO()):
                    result = profile_native_ink.run([sys.executable, '-c', 'import time;time.sleep(0.1)'])
                self.assertEqual(result, 0, 'Native trace must use the selected simulator device context')
                report = json.loads(Path('NativeGPUTrace/process-report.json').read_text())
                self.assertEqual(report['test_exit'], 0)
                self.assertEqual(report['profiler_exit'], 0)
            finally:
                os.chdir(previous)

    def exercise(self, exit_code, discovery, clock=None):
        with tempfile.TemporaryDirectory() as temporary:
            previous = Path.cwd()
            try:
                os.chdir(temporary)
                with contextlib.ExitStack() as stack:
                    stack.enter_context(patch.dict(os.environ, {
                        "GITHUB_SHA": "test-source", "GITHUB_RUN_ID": "1", "SIMULATOR_ID": "test-device"}))
                    stack.enter_context(patch.object(profile_native_ink, "actual_app_pid", **discovery))
                    if clock is not None:
                        stack.enter_context(patch.object(profile_native_ink.time, "monotonic", side_effect=clock))
                    stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
                    code = "import time,pathlib; time.sleep(0.05); pathlib.Path('original-finished').write_text('yes'); raise SystemExit(" + str(exit_code) + ")"
                    result = profile_native_ink.run([sys.executable, "-c", code])
                self.assertTrue(Path("original-finished").is_file(), "Profiling must not kill the original test before it finishes")
                report = json.loads(Path("NativeGPUTrace/process-report.json").read_text())
                self.assertEqual(report["test_exit"], exit_code)
                self.assertTrue(report["errors"])
                self.assertEqual(result, exit_code or 2)
            finally:
                os.chdir(previous)

    def test_discovery_failure_preserves_original_success(self):
        self.exercise(0, {"side_effect": RuntimeError("native PID enumeration unavailable")})

    def test_discovery_failure_preserves_original_failure(self):
        self.exercise(7, {"side_effect": RuntimeError("native PID enumeration unavailable")})

    def test_attachment_deadline_preserves_original_outcome(self):
        self.exercise(0, {"return_value": None}, clock=[0, 0, 200, 200, 200, 200])


if __name__ == "__main__":
    unittest.main()
