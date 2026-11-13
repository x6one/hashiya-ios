"""Execute the actual workflow selector without starting a simulator or Xcode."""
import contextlib
import io
import json
import os
from pathlib import Path
import re
import tempfile
import textwrap
import unittest
from unittest.mock import patch


WORKFLOW = Path(__file__).resolve().parents[1] / ".github/workflows/tayya-integration.yml"


class IntegrationSelectionTests(unittest.TestCase):
    def select(self, marker):
        section = WORKFLOW.read_text().split("      - name: Select available simulator and focused suite\n", 1)[1]
        block = re.search(r"          python3 - <<'PY'\n(.*?)\n          PY", section, re.S)
        self.assertIsNotNone(block)
        code = textwrap.dedent(block.group(1))
        devices = {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-26-2": [
            {"name": "iPhone 17 Pro Max", "udid": "TEST-PHONE"}]}}

        def native_lookup(command, **_):
            self.assertEqual(command, ["xcrun", "simctl", "list", "devices", "available", "--json"])
            return json.dumps(devices).encode()

        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            environment = {"DEVICE_FAMILY": "iPhone", "REQUESTED_SUITE": "",
                           "COMMIT_MESSAGE": "verify [integration:" + marker + "]",
                           "GITHUB_SHA": "a" * 40, "GITHUB_ENV": str(Path(directory) / "env"),
                           "TAYYA_INK_INPUT_PROBE": ""}
            with patch.dict(os.environ, environment), contextlib.redirect_stdout(io.StringIO()):
                with patch("subprocess.check_output", side_effect=native_lookup):
                    try:
                        exec(compile(code, str(WORKFLOW), "exec"), {})
                    except SystemExit as error:
                        self.fail("Workflow rejected a requested test group: " + str(error))
            selected = json.loads(Path("integration-selection.json").read_text())
            self.assertEqual(selected["device"]["udid"], "TEST-PHONE")
            self.assertIn("SIMULATOR_ID=TEST-PHONE", Path(environment["GITHUB_ENV"]).read_text())
            return selected["onlyTesting"]

    def test_red_touch_contract_marker_selects_all_three_requested_cases(self):
        self.assertEqual(self.select("touch-target-red"), [
            "HashiyaUITests/StudioEditorToolsTests/testFavoritePenMenuOpensFromTheLowerEdgeOfItsTouchTarget",
            "HashiyaUITests/LaunchTests/testPagedMarginsKeepInkTextAndNavigationAfterResizeRotationAndRelaunch",
            "HashiyaUITests/LaunchTests/testNotesPencilRemainsVisibleAfterRepeatedNativePaletteDismissals"])

    def test_existing_owned_import_selection_is_preserved(self):
        self.assertEqual(self.select("owned-picker"), [
            "HashiyaUITests/LaunchTests/testAppOwnedDocumentPickerImportsPDF"])


if __name__ == "__main__":
    unittest.main()
