"""Regression checks for native release numbering and Apple's acceptance gate."""
import json
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import yaml
from distribute_native_app import run_apple, validate_release_version
from prepare_native_office_app import prepare


class ReleaseToolsTests(unittest.TestCase):
    def test_engine_preparation_preserves_canonical_version(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            candidate, report = root / "candidate", root / "report"
            candidate.mkdir()
            report.mkdir()
            (candidate / "manifest.json").write_text(json.dumps({"source": "pinned"}))
            (report / "link-report.json").write_text(json.dumps({"source": "pinned", "linked": True}))
            project = root / "project.yml"
            spec = yaml.safe_load(Path("project.yml").read_text())
            spec["settings"]["base"].update(MARKETING_VERSION="9.2.1", CURRENT_PROJECT_VERSION="99")
            project.write_text(yaml.safe_dump(spec))
            generated = json.loads(prepare(candidate, report, project).read_text())
            self.assertEqual(generated["settings"]["base"]["MARKETING_VERSION"], "9.2.1")
            self.assertEqual(generated["settings"]["base"]["CURRENT_PROJECT_VERSION"], "99")

    def test_exported_version_must_match_project(self):
        spec = {"settings": {"base": {"MARKETING_VERSION": "0.4.0", "CURRENT_PROJECT_VERSION": "8"}}}
        validate_release_version({"CFBundleShortVersionString": "0.4.0", "CFBundleVersion": "8"}, spec)
        for version, build in [("0.3.0", "8"), ("0.4.0", "7")]:
            with self.assertRaises(RuntimeError):
                validate_release_version({"CFBundleShortVersionString": version, "CFBundleVersion": build}, spec)

    def test_zero_exit_with_apple_errors_is_rejected(self):
        result = subprocess.CompletedProcess([], 0, plistlib.dumps({"product-errors": [{"code": -19232}]}), b"")
        with patch("distribute_native_app.subprocess.run", return_value=result), self.assertRaises(RuntimeError):
            run_apple(["xcrun", "altool"], "Upload", env={})

    def test_missing_or_invalid_success_response_is_rejected(self):
        for output in [b"", b"not a plist", plistlib.dumps({})]:
            result = subprocess.CompletedProcess([], 0, output, b"")
            with patch("distribute_native_app.subprocess.run", return_value=result), self.assertRaises(RuntimeError):
                run_apple(["xcrun", "altool"], "Upload", env={})

    def test_structured_success_requires_no_error_or_failed_exit(self):
        output = plistlib.dumps({"success-message": "No errors uploading package."})
        for code, stderr in [(1, b""), (0, b"ERROR: rejected")]:
            result = subprocess.CompletedProcess([], code, output, stderr)
            with patch("distribute_native_app.subprocess.run", return_value=result), self.assertRaises(RuntimeError):
                run_apple(["xcrun", "altool"], "Upload", env={})
        result = subprocess.CompletedProcess([], 0, output, b"")
        with patch("distribute_native_app.subprocess.run", return_value=result):
            run_apple(["xcrun", "altool"], "Upload", env={})


if __name__ == "__main__":
    unittest.main()
