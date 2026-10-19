import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

from Tools.trace_color_bootstrap import observe


class ColorBootstrapObserverTests(unittest.TestCase):
    def test_sample_timeout_is_recorded_without_losing_other_processes(self):
        processes = [{"pid": 11, "command": "launchd_sim"},
                     {"pid": 22, "command": "ColorPickerUIService"}]
        stream = Mock()
        stream.poll.return_value = None

        def sample(argv, **kwargs):
            if argv[3] == "11":
                raise subprocess.TimeoutExpired(argv, kwargs["timeout"])
            return subprocess.CompletedProcess(argv, 0)

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            log = root / "test.log"
            log.write_text('Waiting 5.0s for "nativeInkColorPicker" Other to exist\n')
            with patch("Tools.trace_color_bootstrap.selected_processes", return_value=processes), \
                    patch("Tools.trace_color_bootstrap.subprocess.Popen", return_value=stream), \
                    patch("Tools.trace_color_bootstrap.subprocess.run", side_effect=sample):
                observe(log, root / "evidence")
            result = json.loads((root / "evidence/observer.json").read_text())
            samples = {item["pid"]: item for item in result["samples"]}
            self.assertTrue(result["triggered"])
            self.assertTrue(samples[11]["timed_out"])
            self.assertEqual(samples[22]["exit_code"], 0)
            self.assertFalse(result["source_mutated"])


if __name__ == "__main__":
    unittest.main()
