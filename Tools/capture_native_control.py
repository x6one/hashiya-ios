"""Post-test inspection of the isolated control's synthetic Notes, never Tayya data.

The original XCTest/xcresult remains authoritative; rasters are not screenshots.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid

BUNDLE = "com.ahmadalawi.hashiya.native-ink-control"
output = Path("NativeControlEvidence")
output.mkdir(parents=True, exist_ok=True)
status = {"source": os.environ["GITHUB_SHA"], "run": os.environ["GITHUB_RUN_ID"],
          "bundle": BUNDLE, "kind": "post-test synthetic native raster, not screenshot", "errors": []}


def hashes(root):
    paths = list(root.rglob("*"))
    if any(p.is_symlink() for p in paths):
        raise RuntimeError("Synthetic root contains a symlink; inspection refused")
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in paths if p.is_file()}


try:
    device = os.environ["SIMULATOR_ID"]
    container = Path(subprocess.check_output(
        ["xcrun", "simctl", "get_app_container", device, BUNDLE, "data"], text=True, timeout=30).strip())
    temporary = container / "tmp"
    roots = []
    for path in temporary.glob("ReviewEntry-*"):
        try:
            uuid.UUID(path.name.removeprefix("ReviewEntry-"))
        except ValueError:
            continue
        if path.is_dir() and not path.is_symlink():
            roots.append(path)
    if not roots:
        raise RuntimeError("No diagnostic synthetic root; no other directory will be inspected")
    before = {root.name: hashes(root) for root in roots}
    status["original_files"] = before
    for root in roots:
        shutil.copytree(root, output / "OriginalRoots" / root.name)
    subprocess.run(["xcrun", "simctl", "launch", "--terminate-running-process", device,
                    BUNDLE, "--test-inspect-review-ink"], check=True, timeout=30)
    inspection = temporary / "TayyaInkInspection"
    deadline = time.monotonic() + 20
    while not (inspection / "report.json").is_file():
        if time.monotonic() >= deadline:
            raise TimeoutError("Native inspection did not publish its atomic report within20s")
        time.sleep(0.2)
    hashes(inspection)  # Reject links before copying generated diagnostic files too.
    shutil.copytree(inspection, output / "NativeRasters")
    status["inputs_unchanged"] = before == {root.name: hashes(root) for root in roots}
    if not status["inputs_unchanged"]:
        raise RuntimeError("Inspection modified original synthetic bytes")
except (OSError, subprocess.SubprocessError, RuntimeError) as error:
    status["errors"].append(str(error))
finally:
    (output / "collection.json").write_text(json.dumps(status, indent=2) + "\n")
    print(json.dumps({key: value for key, value in status.items() if key != "original_files"}))
