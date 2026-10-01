"""Start Files; XCTest creates its folder and exports fixtures through native UI.

The native Save operation creates provider-owned document IDs. Host-side byte
verification runs after the real Files import tests, never imports into the app.
"""
import hashlib
import os
import re
import subprocess
import sys
from pathlib import Path

simulator = os.environ["SIMULATOR_ID"]
verify = "--verify" in sys.argv
if not verify:
    subprocess.run(["xcrun", "simctl", "launch", simulator, "com.apple.DocumentsApp"], check=True)
groups = subprocess.check_output(
    ["xcrun", "simctl", "get_app_container", simulator, "com.apple.DocumentsApp", "groups"], text=True)
row = next(line for line in groups.splitlines() if "group.com.apple.FileProvider.LocalStorage" in line)
match = re.search(r"(/.*)$", row)
if not match:
    raise RuntimeError("Files LocalStorage container path was not returned")
folder = Path(match.group(1).strip()) / "File Provider Storage" / "Tayya-test-files"
if not verify:
    print("Files provider started; XCTest must create its folder and export fixtures through native UI", flush=True)
else:
    for name, target in [("english.pdf", "Picker-fixture.pdf"), ("office-demo.pptx", "Picker-office.pptx")]:
        sources = list(Path("App").rglob(name))
        if len(sources) != 1:
            raise RuntimeError(f"Expected one fixture: {name}")
        destination = folder / target
        if hashlib.sha256(sources[0].read_bytes()).digest() != hashlib.sha256(destination.read_bytes()).digest():
            raise RuntimeError(f"Exported fixture bytes differ: {name}")
        print(f"Files-exported fixture verified: {target} ({destination.stat().st_size} bytes)", flush=True)
