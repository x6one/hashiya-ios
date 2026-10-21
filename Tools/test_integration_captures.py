import base64
import hashlib
import json
from pathlib import Path
import tempfile
import struct
import zlib
import unittest

from Tools.collect_integration_captures import collect, stage


class NativeCaptureIndexTests(unittest.TestCase):
    def fixture(self, root):
        images = root / "Screenshots"
        images.mkdir()
        png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aB1kAAAAASUVORK5CYII=")
        (images / "native.png").write_bytes(png)
        metadata = dict(screen="Editor", orientation="portrait", font_size="AX5", color_mode="dark", language="ar", metadata_origin="native test", pixel_width=1, pixel_height=1, window_width=1, window_height=1, png_orientation=1)
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

    def test_staged_small_evidence_keeps_original_pixels_metadata_and_test_link(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            evidence = root / "raw"; evidence.mkdir()
            png, manifest = self.fixture(evidence)
            (evidence / "Screenshots/video.mp4").write_bytes(b"unrelated large diagnostic")
            manifest[0]["attachments"].append(dict(exportedFileName="video.mp4", suggestedHumanReadableName="Screen Recording"))
            (evidence / "Screenshots/manifest.json").write_text(json.dumps(manifest))
            output = root / "staged"
            self.assertEqual(stage(evidence / "summary.json", evidence / "Screenshots", output, "a" * 40, "iPhone", 123), 2)
            self.assertFalse((output / "Screenshots/video.mp4").exists())
            row = collect(output, "a" * 40, "iPhone", 123, 456)[0]
            self.assertEqual((output / row["file"]).read_bytes(), png)
            with self.assertRaisesRegex(ValueError, "overwritten"):
                stage(evidence / "summary.json", evidence / "Screenshots", output, "a" * 40, "iPhone", 123)

    def test_native_pixel_and_window_metadata_cannot_disguise_wrong_orientation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.fixture(root)
            metadata = root / "Screenshots/meta.json"
            row = json.loads(metadata.read_text())
            row['pixel_width'] = 100
            metadata.write_text(json.dumps(row))
            with self.assertRaisesRegex(ValueError, "PNG dimensions"):
                collect(root, "a" * 40, "iPhone", 123, 456)
            row['pixel_width'] = 1
            row['window_width'] = 2
            metadata.write_text(json.dumps(row))
            with self.assertRaisesRegex(ValueError, "window aspect"):
                collect(root, "a" * 40, "iPhone", 123, 456)

    def test_native_exif_orientation_is_read_without_rotating_original_png_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.fixture(root)
            def chunk(kind, content):
                return struct.pack('>I', len(content)) + kind + content + struct.pack('>I', zlib.crc32(kind + content))
            # Real PNG grammar with2x3raw pixels and the same TIFF orientation
            # tag8 used by original landscape XCUIScreen captures.
            tiff = b'MM' + struct.pack('>HIH', 42, 8, 1) + struct.pack('>HHIHHI', 274, 3, 1, 8, 0, 0)
            png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 2, 3, 8, 6, 0, 0, 0))
            png += chunk(b'eXIf', tiff) + chunk(b'IDAT', zlib.compress((b'\x00' + b'\xff\xff\xff\xff' * 2) * 3)) + chunk(b'IEND', b'')
            (root / 'Screenshots/native.png').write_bytes(png)
            metadata = root / 'Screenshots/meta.json'
            row = json.loads(metadata.read_text())
            row.update(orientation='landscape', pixel_width=2, pixel_height=3, window_width=3, window_height=2, png_orientation=8)
            manifest = root / 'Screenshots/manifest.json'
            manifest.write_text(manifest.read_text().replace('-portrait_', '-landscape_'))
            metadata.write_text(json.dumps(row))
            result = collect(root, 'a' * 40, 'iPhone', 123, 456)[0]
            self.assertEqual(result['sha256'], hashlib.sha256(png).hexdigest())
            self.assertEqual((root / result['file']).read_bytes(), png)
            self.assertEqual(result['display_pixel_width'], 3)
            row['png_orientation'] = 1
            metadata.write_text(json.dumps(row))
            with self.assertRaisesRegex(ValueError, 'PNG orientation'):
                collect(root, 'a' * 40, 'iPhone', 123, 456)
