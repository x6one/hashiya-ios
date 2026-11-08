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

    def test_copies_all_144_originals_byte_exact_with_named_preview_and_digest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); rows = self.fixture(root)
            result = build(root, rows, root / 'result')
            self.assertEqual(len(result), 144)
            for row in result:
                original = root / (row['orientation'] + '.png')
                self.assertEqual((root / 'result' / row['file']).read_bytes(), original.read_bytes())
                self.assertEqual(row['sha256'], hashlib.sha256(original.read_bytes()).hexdigest())
            self.assertIn('النسخ الاحتياطي والاستعادة', (root / 'result/index.html').read_text())
            self.assertEqual(len(json.loads((root / 'result/features.json').read_text())), 144)

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


class VerifiedOriginalCasesTests(unittest.TestCase):
    def evidence(self, mode):
        color = mode.title()
        failed = {f'StudioProductionCaptureTests/testIPad{color}{direction}Audio()' for direction in ['Portrait', 'Landscape']}
        if mode == 'dark':
            failed |= {'StudioProductionCaptureTests/testIPadDarkPortraitDocument()', 'StudioProductionCaptureTests/testIPadDarkPortraitLibrary()'}
        rows = []
        for direction in ['Portrait', 'Landscape']:
            for feature in ['Audio', 'Cards', 'Document', 'Library', 'Notes']:
                key = f'StudioProductionCaptureTests/testIPad{color}{direction}{feature}()'
                rows.append(dict(nodeType='Test Case', nodeIdentifier=key, result='Failed' if key in failed else 'Passed'))
        failures = [dict(testIdentifierString=k, failureText='Failed to tap "pauseLinkedRecording" Button: Multiple matching elements found recordingStrip CollectionView' if k.endswith('Audio()') else 'Capture waits for native orientation and compositor readiness') for k in sorted(failed)]
        summary = dict(result='Failed', totalTestCount=10, passedTests=10-len(failed), failedTests=len(failed), skippedTests=0, expectedFailures=0, testFailures=failures)
        return summary, dict(testNodes=[dict(nodeType='Test Suite', children=rows)])

    def test_selects_only_individually_passed_original_cases_and_preserves_failed_result(self):
        from Tools.build_ipad_feature_gallery import verified_core_cases
        for mode, expected in [('light', 8), ('dark', 6)]:
            summary, tests = self.evidence(mode)
            before = json.dumps(summary, sort_keys=True)
            selected = verified_core_cases(summary, tests, mode)
            self.assertEqual(len(selected), expected)
            self.assertFalse(any(k.endswith('Audio()') for k in selected))
            self.assertEqual(json.dumps(summary, sort_keys=True), before)
            self.assertEqual(summary['result'], 'Failed')

    def test_an_additional_failed_or_skipped_original_case_is_never_silently_filtered(self):
        from Tools.build_ipad_feature_gallery import verified_core_cases
        for status in ['Failed', 'Skipped']:
            summary, tests = self.evidence('light')
            tests['testNodes'][0]['children'][1]['result'] = status
            with self.assertRaises(ValueError):
                verified_core_cases(summary, tests, 'light')

    def test_original_summary_and_native_case_tree_must_agree(self):
        from Tools.build_ipad_feature_gallery import verified_core_cases
        summary, tests = self.evidence('dark')
        summary['passedTests'] = 8
        with self.assertRaises(ValueError):
            verified_core_cases(summary, tests, 'dark')
