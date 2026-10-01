"""Choose the installed Xcode 26 toolchain for app builds and iOS 26 tests.

The engine's existing archive compiler/cache is selected before this step.
No downloads or changes to signing settings are performed.
"""
import re
import subprocess
from pathlib import Path

candidates = []
for path in Path("/Applications").glob("Xcode_*.app"):
    match = re.fullmatch(r"Xcode_(\d+)\.(\d+)(?:\.(\d+))?\.app", path.name)
    if match:
        version = tuple(int(n or 0) for n in match.groups())
        if version >= (26, 2, 0):
            candidates.append((version, path))
if not candidates:
    raise SystemExit("Xcode 26.2 or newer is required for the iOS 26 app/test build")
# Prefer 26.2 to match the runtime being investigated; use a newer stable
# installed toolchain if the image only retains that version.
matching = [row for row in candidates if row[0][:2] == (26, 2)]
version, path = max(matching or candidates)
subprocess.run(["sudo", "xcode-select", "--switch", str(path / "Contents/Developer")], check=True)
subprocess.run(["xcodebuild", "-version"], check=True)
subprocess.run(["xcrun", "--sdk", "iphoneos", "--show-sdk-version"], check=True)
print("Selected app toolchain:", path, flush=True)
