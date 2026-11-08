"""Test-only generated PNGs never become real Tayya capture evidence."""
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib
from Tools.build_ipad_feature_gallery import build, SCENES


def png(width, height):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(b'\0' * ((width * 3 + 1) * height))) + chunk(b'IEND', b'')


class IPadPhotographyTests(unittest.TestCase):
    def fixture(self, root):
        rows = []
        for direction, width, height in [('portrait', 2064, 2752), ('landscape', 2752, 2064)]:
            name = direction + '.png'
            raw = png(width, height)
            (root / name).write_bytes(raw)
            for mode in ['light', 'dark']:
                for scene in SCENES:
                    rows.append(dict(scene=scene, family='iPad', orientation=direction, color_mode=mode,
                                     file=name, sha256=hashlib.sha256(raw).hexdigest(), device='test-only synthetic fixture',
                                     png_width=width, png_height=height, display_pixel_width=width, display_pixel_height=height,
                                     source='a' * 40, test_url='https://github.com/x6one/hashiya-ios/actions/runs/1/job/2'))
        return rows

    def test_copies_all_128_originals_byte_exact_with_named_preview_and_digest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); rows = self.fixture(root)
            result = build(root, rows, root / 'result')
            self.assertEqual(len(result), 128)
            for row in result:
                original = root / (row['orientation'] + '.png')
                self.assertEqual((root / 'result' / row['file']).read_bytes(), original.read_bytes())
                self.assertEqual(row['sha256'], hashlib.sha256(original.read_bytes()).hexdigest())
            self.assertIn('النسخ الاحتياطي والاستعادة', (root / 'result/index.html').read_text())
            self.assertEqual(len(json.loads((root / 'result/features.json').read_text())), 128)

    def test_missing_dark_landscape_feature_cannot_be_called_complete(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); rows = self.fixture(root)
            with self.assertRaisesRegex(ValueError, 'Missing'):
                build(root, rows[:-1], root / 'result')
            self.assertFalse((root / 'result').exists())

    def test_rejects_original_bytes_changed_after_native_collection(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); rows = self.fixture(root)
            (root / 'portrait.png').write_bytes(b'changed original')
            with self.assertRaisesRegex(ValueError, 'Original'):
                build(root, rows, root / 'result')
