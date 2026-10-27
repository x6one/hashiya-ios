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
