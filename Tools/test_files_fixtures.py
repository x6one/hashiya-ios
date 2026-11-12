"""Exercise real native-export destinations and bytes; mock only simctl lookup."""
import contextlib
import io
import os
from pathlib import Path
import runpy
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).with_name('seed_files_fixtures.py').resolve()


class FilesFixtureTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.previous_cwd = Path.cwd()
        os.chdir(self.root)
        self.addCleanup(os.chdir, self.previous_cwd)
        self.provider = self.root / 'current-provider'
        self.documents = self.root / 'current-app' / 'Documents'
        (self.provider / 'File Provider Storage').mkdir(parents=True)
        self.documents.mkdir(parents=True)
        Path('App/Fixtures').mkdir(parents=True)
        self.fixtures = [('english.pdf', 'Picker-fixture.pdf', b'%PDF real fixture bytes'),
                         ('office-demo.pptx', 'Picker-office.pptx', b'PK office fixture bytes')]
        for source, _, data in self.fixtures:
            (Path('App/Fixtures') / source).write_bytes(data)

    def export_to(self, folder):
        for _, target, data in self.fixtures:
            (folder / target).write_bytes(data)

    def verify(self):
        def lookup(command, **kwargs):
            if command == ['xcrun', 'simctl', 'get_app_container', 'current-simulator',
                           'com.apple.DocumentsApp', 'groups']:
                return 'group.com.apple.FileProvider.LocalStorage: ' + str(self.provider) + '\n'
            if command == ['xcrun', 'simctl', 'get_app_container', 'current-simulator',
                           'com.ahmadalawi.hashiya', 'data']:
                return str(self.documents.parent) + '\n'
            raise AssertionError('Unexpected simctl command: ' + repr(command))
        output = io.StringIO()
        with patch.dict(os.environ, {'SIMULATOR_ID': 'current-simulator'}), \
                patch.object(sys, 'argv', [str(SCRIPT), '--verify']), \
                patch('subprocess.check_output', side_effect=lookup), \
                contextlib.redirect_stdout(output):
            runpy.run_path(str(SCRIPT), run_name='__main__')
        return output.getvalue()

    def test_setup_releases_files_foreground_without_touching_exports(self):
        self.export_to(self.provider / 'File Provider Storage')
        self.export_to(self.documents)
        before = {str(path.relative_to(self.root)): path.read_bytes()
                  for folder in (self.provider, self.documents)
                  for path in folder.rglob('*') if path.is_file()}
        foreground = [None]

        def command(arguments, **kwargs):
            self.assertTrue(kwargs.get('check'))
            if arguments == ['xcrun', 'simctl', 'launch', 'current-simulator',
                             'com.apple.DocumentsApp']:
                foreground[0] = 'com.apple.DocumentsApp'
            elif arguments == ['xcrun', 'simctl', 'terminate', 'current-simulator',
                               'com.apple.DocumentsApp']:
                foreground[0] = None
            else:
                raise AssertionError('Unexpected setup mutation: ' + repr(arguments))

        def lookup(arguments, **kwargs):
            self.assertEqual(foreground[0], 'com.apple.DocumentsApp')
            self.assertEqual(arguments, ['xcrun', 'simctl', 'get_app_container',
                'current-simulator', 'com.apple.DocumentsApp', 'groups'])
            return 'group.com.apple.FileProvider.LocalStorage: ' + str(self.provider) + '\n'

        with patch.dict(os.environ, {'SIMULATOR_ID': 'current-simulator'}), \
                patch.object(sys, 'argv', [str(SCRIPT)]), \
                patch('subprocess.run', side_effect=command), \
                patch('subprocess.check_output', side_effect=lookup), \
                contextlib.redirect_stdout(io.StringIO()):
            runpy.run_path(str(SCRIPT), run_name='__main__')
        after = {str(path.relative_to(self.root)): path.read_bytes()
                 for folder in (self.provider, self.documents)
                 for path in folder.rglob('*') if path.is_file()}
        self.assertEqual(after, before, 'Setup must preserve actual exported bytes')
        self.assertIsNone(foreground[0], 'Setup must release Files before XCTest launches Tayya')

    def test_provider_root_exact_exports(self):
        self.export_to(self.provider / 'File Provider Storage')
        result = self.verify()
        self.assertIn('Picker-fixture.pdf', result)
        self.assertIn('Picker-office.pptx', result)

    def test_app_documents_exact_exports(self):
        self.export_to(self.documents)
        result = self.verify()
        self.assertIn('Picker-fixture.pdf', result)
        self.assertIn('Picker-office.pptx', result)

    def test_duplicate_destinations_are_rejected(self):
        self.export_to(self.provider / 'File Provider Storage')
        self.export_to(self.documents)
        with self.assertRaisesRegex(RuntimeError, 'Expected exactly one native export'):
            self.verify()

    def test_missing_export_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, 'Expected exactly one native export'):
            self.verify()

    def test_corrupt_export_is_rejected(self):
        self.export_to(self.documents)
        (self.documents / 'Picker-fixture.pdf').write_bytes(b'corrupt bytes')
        with self.assertRaisesRegex(RuntimeError, 'Exported fixture bytes differ'):
            self.verify()

    def test_current_simctl_container_ignores_stale_provider(self):
        stale = self.root / 'stale-provider' / 'File Provider Storage'
        stale.mkdir(parents=True)
        self.export_to(stale)
        self.provider = self.root / 'replacement-provider'
        (self.provider / 'File Provider Storage').mkdir(parents=True)
        with self.assertRaisesRegex(RuntimeError, 'Expected exactly one native export'):
            self.verify()
        self.export_to(self.provider / 'File Provider Storage')
        self.assertIn('Picker-fixture.pdf', self.verify())


if __name__ == '__main__':
    unittest.main()
