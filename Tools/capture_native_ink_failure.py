"""Preserve synthetic review files before a separate, read-only native inspection.

macOS simulator diagnostic only; never reads the app's Documents/user library.
The failed XCTest result remains authoritative even if evidence collection fails.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid

device = os.environ["SIMULATOR_ID"]
output = Path("IntegrationEvidence/NativeInkFailure")
output.mkdir(parents=True, exist_ok=True)
status = {"sha": os.environ["GITHUB_SHA"], "run": os.environ["GITHUB_RUN_ID"], "errors": []}


def hashes(root):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob("*") if p.is_file() and not p.is_symlink()}


try:
    container = Path(subprocess.check_output(
        ["xcrun", "simctl", "get_app_container", device, "com.ahmadalawi.hashiya", "data"],
        text=True, timeout=30).strip())
    temporary = container / "tmp"
    roots = []
    for path in temporary.glob("ReviewEntry-*"):
        try:
            uuid.UUID(path.name.removeprefix("ReviewEntry-"))
        except ValueError:
            continue
        if path.is_dir() and not path.is_symlink():
            roots.append(path)
    before = {root.name: hashes(root) for root in roots}
    status["original_files"] = before
    for root in roots:
        shutil.copytree(root, output / "OriginalReviewRoots" / root.name)
    if not roots:
        raise RuntimeError("No synthetic review root exists; no user library will be inspected")
    subprocess.run(["xcrun", "simctl", "launch", "--terminate-running-process", device,
                    "com.ahmadalawi.hashiya", "--test-review-entry", "--test-inspect-review-ink"],
                   check=True, timeout=30)
    inspection = temporary / "TayyaInkInspection"
    deadline = time.monotonic() + 20
    while not (inspection / "report.json").is_file():
        if time.monotonic() >= deadline:
            raise TimeoutError("Native inspection did not publish its atomic report")
        time.sleep(0.2)
    shutil.copytree(inspection, output / "NativeRasters")
    status["inputs_unchanged"] = before == {root.name: hashes(root) for root in roots}
    if not status["inputs_unchanged"]:
        raise RuntimeError("Native inspection changed original synthetic input bytes")
except (OSError, subprocess.SubprocessError, RuntimeError) as error:
    status["errors"].append(str(error))

try:
    predicate = 'process == "Hashiya" OR subsystem CONTAINS[c] "pencil" OR subsystem CONTAINS[c] "metal" OR process == "runningboardd"'
    with (output / "native-system.log").open("wb") as log:
        subprocess.run(["xcrun", "simctl", "spawn", device, "log", "show", "--last", "15m",
                        "--style", "compact", "--info", "--debug", "--predicate", predicate],
                       stdout=log, stderr=subprocess.STDOUT, timeout=45, check=True)
except (OSError, subprocess.SubprocessError) as error:
    status["errors"].append("System log: " + str(error))
finally:
    (output / "collection.json").write_text(json.dumps(status, indent=2) + "\n")
    print(json.dumps({key: value for key, value in status.items() if key != "original_files"}))
