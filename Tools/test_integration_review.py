import base64
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from build_integration_review import build


class IntegrationReviewTests(unittest.TestCase):
    def capture(self, root):
        # Tiny test-only PNG; never used as application review evidence.
        pixels = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=")
        (root / "capture.png").write_bytes(pixels)
        return {"scene": "editor", "family": "iPhone", "orientation": "portrait", "font_size": "default",
                "color_mode": "light", "language": "ar", "file": "capture.png", "source": "a" * 40,
                "test_url": "https://github.com/x6one/hashiya-ios/actions/runs/1", "device": "test fixture",
                "sha256": hashlib.sha256(pixels).hexdigest()}

    def testOriginalBytesAndHashesArePreservedAndMismatchedContextsAreNotPaired(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            capture = self.capture(root)
            output = root / "review"
            result = build(root, [capture], root, [capture], output)
            self.assertIsNotNone(result[0]["before"])
            for phase in ["before", "after"]:
                self.assertEqual((output / result[0][phase]["file"]).read_bytes(), (root / "capture.png").read_bytes())
            for path, digest in json.loads((output / "SHA256.json").read_text()).items():
                self.assertEqual(hashlib.sha256((output / path).read_bytes()).hexdigest(), digest)
            different = dict(capture, language="en")
            result = build(root, [capture], root, [different], root / "different")
            self.assertIsNone(result[0]["before"], "Arabic is not an English before/after comparison")

    def testDifferentModelsWithinOneFamilyAreExplicitlyDisclosed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            before = self.capture(root)
            after = dict(before, device="larger production test device")
            result = build(root, [before], root, [after], root / "review")
            self.assertFalse(result[0]["same_device_model"])
            self.assertNotEqual(result[0]["comparison"], "exact capture context")
            self.assertIn("الطراز وحجم الشاشة مختلفان", (root / "review/index.html").read_text())

    def testHashMismatchAndIncompleteMetadataCannotBecomeReviewEvidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            capture = self.capture(root)
            for bad in [dict(capture, sha256="0" * 64), dict(capture, source=""), dict(capture, test_url="javascript:alert(1)")]:
                output = root / "invalid"
                with self.assertRaises(ValueError):
                    build(root, [], root, [bad], output)
                self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
