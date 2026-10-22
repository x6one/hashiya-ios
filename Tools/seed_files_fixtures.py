"""Start Files; XCTest exports fixtures through native UI to On My device.

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
folder = Path(match.group(1).strip()) / "File Provider Storage"
if not verify:
    # Release the setup app before XCTest launches Tayya. Provider data persists.
    try:
        subprocess.run(["xcrun", "simctl", "terminate", simulator, "com.apple.DocumentsApp"],
                       check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as error:
        message = (error.stdout or "") + "\n" + (error.stderr or "")
        already_stopped = (error.returncode == 3
                           and re.search(r"\bdomain=NSPOSIXErrorDomain,\s*code=3\b", message)
                           and "found nothing to terminate" in message)
        if not already_stopped:
            print(message.strip(), file=sys.stderr, flush=True)
            raise
        print("Files already stopped (ESRCH); native provider lookup succeeded", flush=True)
    print("Files provider initialized and foreground released; XCTest must export fixtures through native UI", flush=True)
else:
    app_data = subprocess.check_output(
        ["xcrun", "simctl", "get_app_container", simulator, "com.ahmadalawi.hashiya", "data"], text=True).strip()
    if not app_data or not Path(app_data).is_absolute():
        raise RuntimeError("Installed app data container path was not returned")
    documents = Path(app_data) / "Documents"
    for name, target in [("english.pdf", "Picker-fixture.pdf"), ("office-demo.pptx", "Picker-office.pptx")]:
        sources = list(Path("App").rglob(name))
        if len(sources) != 1:
            raise RuntimeError(f"Expected one fixture: {name}")
        # Native Save may choose the provider root or Tayya's visible Documents
        # folder. Inspect only these two exact filenames, never UUID/hash matches.
        destinations = [path for path in (folder / target, documents / target) if path.is_file()]
        if len(destinations) != 1:
            raise RuntimeError(f"Expected exactly one native export: {target}; found {len(destinations)}")
        destination = destinations[0]
        if hashlib.sha256(sources[0].read_bytes()).digest() != hashlib.sha256(destination.read_bytes()).digest():
            raise RuntimeError(f"Exported fixture bytes differ: {name}")
        print(f"Files-exported fixture verified: {target} ({destination.stat().st_size} bytes)", flush=True)
