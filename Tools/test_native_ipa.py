import plistlib
from pathlib import Path
import tempfile
import unittest
import zipfile

from Tools.verify_native_ipa import verify_archive


class NativeIPAArchiveTests(unittest.TestCase):
    def fixture(self, root, extra=None, omit=None):
        info = dict(CFBundleIdentifier='com.ahmadalawi.hashiya', CFBundleExecutable='Hashiya',
                    CFBundleShortVersionString='0.6.0', CFBundleVersion='13', UIDeviceFamily=[1, 2])
        entries = {'Payload/Hashiya.app/Info.plist': plistlib.dumps(info),
                   'Payload/Hashiya.app/Hashiya': b'unit archive executable bytes',
                   'Payload/Hashiya.app/fundamentalrc': b'engine configuration',
                   'Payload/Hashiya.app/services.rdb': b'engine services',
                   'Payload/Hashiya.app/share/fonts/truetype/font.ttf': b'font bytes',
                   'Payload/Hashiya.app/OfficeEngineNotices/engine-manifest.json': b'{}'}
        if omit: entries.pop(omit)
        entries.update(extra or {})
        path = root / 'candidate.ipa'
        with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            for name, content in entries.items(): archive.writestr(name, content)
        return path, info, entries

    def test_zip_crc_payload_metadata_and_executable_bytes_are_verified(self):
        with tempfile.TemporaryDirectory() as folder:
            path, info, entries = self.fixture(Path(folder))
            result = verify_archive(path, info, entries['Payload/Hashiya.app/Hashiya'])
            self.assertTrue(result['zip_crc_verified'])
            self.assertEqual(result['app'], 'Payload/Hashiya.app')
            self.assertEqual(result['files'], len(entries))
            self.assertEqual(result['embedded_frameworks'], [])
            with self.assertRaisesRegex(ValueError, 'executable bytes'):
                verify_archive(path, info, b'different executable')

    def test_wrong_metadata_missing_engine_resources_or_unsafe_payload_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            path, info, entries = self.fixture(root, omit='Payload/Hashiya.app/services.rdb')
            with self.assertRaisesRegex(ValueError, 'services.rdb'):
                verify_archive(path, info, entries['Payload/Hashiya.app/Hashiya'])
            path, info, entries = self.fixture(root, extra={'../outside': b'bad'})
            with self.assertRaisesRegex(ValueError, 'Unsafe'):
                verify_archive(path, info, entries['Payload/Hashiya.app/Hashiya'])
            path, info, entries = self.fixture(root)
            info['CFBundleVersion'] = '14'
            with self.assertRaisesRegex(ValueError, 'metadata'):
                verify_archive(path, info, entries['Payload/Hashiya.app/Hashiya'])
