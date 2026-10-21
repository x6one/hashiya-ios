import base64
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from Tools.collect_integration_captures import collect


class NativeCaptureIndexTests(unittest.TestCase):
    def fixture(self, root):
        images = root / "Screenshots"
        images.mkdir()
        png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aB1kAAAAASUVORK5CYII=")
        (images / "native.png").write_bytes(png)
        metadata = dict(screen="Editor", orientation="portrait", font_size="AX5", color_mode="dark", language="ar", metadata_origin="native test")
        (images / "meta.json").write_text(json.dumps(metadata))
        attachments = [dict(exportedFileName="native.png", suggestedHumanReadableName="ProductionScene-Editor-portrait_0_UUID.png", deviceName="iPhone 17 Pro Max"),
                       dict(exportedFileName="meta.json", suggestedHumanReadableName="ProductionMetadata-Editor-portrait_0_UUID.json")]
        manifest = [dict(testIdentifier="StudioProductionCaptureTests/testEditor()", attachments=attachments)]
        (images / "manifest.json").write_text(json.dumps(manifest))
        (root / "summary.json").write_text(json.dumps(dict(result="Passed", passedTests=1, failedTests=0, skippedTests=0, expectedFailures=0)))
        return png, manifest

    def test_indexes_exact_native_bytes_with_test_device_and_context(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            png, _ = self.fixture(root)
            record = collect(root, "a" * 40, "iPhone", 123, 456)[0]
            self.assertEqual(record["sha256"], hashlib.sha256(png).hexdigest())
            self.assertEqual(record["font_size"], "AX5")
            self.assertEqual(record["test_url"], "https://github.com/x6one/hashiya-ios/actions/runs/123/job/456")
            self.assertEqual((root / record["file"]).read_bytes(), png)

    def test_missing_metadata_and_wrong_device_cannot_be_assumed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            _, manifest = self.fixture(root)
            with self.assertRaisesRegex(ValueError, "device"):
                collect(root, "a" * 40, "iPad", 123, 456)
            manifest[0]["attachments"].pop()
            (root / "Screenshots/manifest.json").write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, "metadata"):
                collect(root, "a" * 40, "iPhone", 123, 456)

    def test_failed_summary_and_escaping_attachment_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            _, manifest = self.fixture(root)
            (root / "summary.json").write_text(json.dumps(dict(result="Failed", failedTests=1)))
            with self.assertRaisesRegex(ValueError, "Failed"):
                collect(root, "a" * 40, "iPhone", 123, 456)
            (root / "summary.json").write_text(json.dumps(dict(result="Passed", passedTests=1)))
            manifest[0]["attachments"][0]["exportedFileName"] = "../../outside.png"
            (root / "Screenshots/manifest.json").write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, "escapes"):
                collect(root, "a" * 40, "iPhone", 123, 456)
