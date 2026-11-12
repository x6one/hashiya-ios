"""Recover byte-preserved approved PNGs from an earlier production gallery.

No generated images, replacement source labels, recapture or transformations.
The workflow verifies the outer immutable artifact's source, size and SHA256.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import tempfile
import zipfile

from Tools.build_integration_review import REQUIRED, validated_capture

APPROVED_SOURCE = 'e94c2cbb6f6914e0ebb21ded090beaa54013e4df'
PREFIX = 'Tayya-Production-Review/'


def restore(archive: Path, output: Path):
    if output.exists():
        raise ValueError('Existing output must never be overwritten')
    recovered = {}
    with zipfile.ZipFile(archive) as zipped:
        pairs = json.loads(zipped.read(PREFIX + 'captures.json'))
        for pair in pairs:
            row = pair.get('before')
            if row is None:
                continue
            if row.get('source') != APPROVED_SOURCE:
                raise ValueError('Approved source mismatch')
            file = row.get('file')
            path = PurePosixPath(file) if isinstance(file, str) else PurePosixPath('/')
            if path.is_absolute() or '..' in path.parts or '\\' in str(path) or not str(path).startswith('images/'):
                raise ValueError('Unsafe approved image path')
            if any(not row.get(key) for key in REQUIRED):
                raise ValueError('Incomplete approved capture metadata')
            member = PREFIX + str(path)
            if zipped.namelist().count(member) != 1 or zipped.getinfo(member).file_size > 32 * 1024**2:
                raise ValueError('Ambiguous or oversized approved image')
            pixels = zipped.read(member)
            if hashlib.sha256(pixels).hexdigest() != row['sha256']:
                raise ValueError('Approved PNG hash mismatch')
            if not pixels.startswith(b'\x89PNG\r\n\x1a\n'):
                raise ValueError('Approved capture is not an original PNG')
            if str(path) in recovered and recovered[str(path)][0] != row:
                raise ValueError('Conflicting approved metadata')
            recovered[str(path)] = (row, pixels)
    if not recovered or sum(len(pixels) for _, pixels in recovered.values()) > 128 * 1024**2:
        raise ValueError('Missing or oversized approved reference set')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='approved-restore-', dir=output.parent) as temporary:
        staged = Path(temporary) / 'approved'
        staged.mkdir()
        rows = []
        for file, (row, pixels) in recovered.items():
            target = staged / file
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(pixels)
            validated_capture(staged, row)
            rows.append(row)
        (staged / 'all-images.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n')
        staged.rename(output)
    return len(recovered)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print('Recovered approved byte-exact PNGs:', restore(args.archive, args.output))
