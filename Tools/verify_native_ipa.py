"""Verify the packaged unsigned app's original ZIP bytes and native resources."""
import plistlib
from pathlib import Path, PurePosixPath
import zipfile


def verify_archive(path: Path, expected_info: dict, expected_executable: bytes) -> dict:
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        names = [entry.filename for entry in entries]
        if len(set(names)) != len(names):
            raise ValueError('Duplicate IPA ZIP members')
        for name in names:
            parts = PurePosixPath(name).parts
            if name.startswith('/') or '..' in parts or not parts or parts[0] != 'Payload':
                raise ValueError('Unsafe IPA ZIP member: ' + name)
        apps = {name.split('/')[1] for name in names if name.startswith('Payload/') and len(name.split('/')) > 1 and name.split('/')[1].endswith('.app')}
        if len(apps) != 1:
            raise ValueError('Expected exactly one Payload/*.app')
        app = 'Payload/' + apps.pop()
        if any(not (name == 'Payload/' or name == app + '/' or name.startswith(app + '/')) for name in names):
            raise ValueError('Unexpected content outside the production app')
        invalid = archive.testzip()
        if invalid is not None:
            raise ValueError('IPA ZIP CRC mismatch: ' + invalid)
        info = plistlib.loads(archive.read(app + '/Info.plist'))
        if info != expected_info:
            raise ValueError('Packaged Info.plist metadata differs from the verified device app')
        executable = archive.read(app + '/' + info['CFBundleExecutable'])
        if executable != expected_executable or not executable:
            raise ValueError('Packaged executable bytes differ from the arm64 device app')
        for resource in ['fundamentalrc', 'services.rdb', 'OfficeEngineNotices/engine-manifest.json']:
            member = app + '/' + resource
            if member not in names or archive.getinfo(member).file_size == 0:
                raise ValueError('Missing packaged native resource: ' + resource)
        fonts = app + '/share/fonts/truetype/'
        if not any(name.startswith(fonts) and not name.endswith('/') and archive.getinfo(name).file_size > 0 for name in names):
            raise ValueError('Missing packaged native Office fonts')
        frameworks = sorted({name.split('/')[3] for name in names if name.startswith(app + '/Frameworks/') and len(name.split('/')) > 3 and name.split('/')[3].endswith('.framework')})
        for framework in frameworks:
            binary = app + '/Frameworks/' + framework + '/' + framework.removesuffix('.framework')
            if binary not in names or archive.getinfo(binary).file_size == 0:
                raise ValueError('Missing embedded framework executable: ' + framework)
        return dict(zip_crc_verified=True, app=app, files=sum(not entry.is_dir() for entry in entries),
                    uncompressed_bytes=sum(entry.file_size for entry in entries), embedded_frameworks=frameworks)
