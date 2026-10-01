"""Seed external input files in the simulator's Files provider, never the app.

XCTest must still browse, tap, import, and open each document through Files.
No library index or application data is written by this script.
"""
import hashlib
import os
import platform
import re
import subprocess
from pathlib import Path

simulator = os.environ["SIMULATOR_ID"]
subprocess.run(["xcrun", "simctl", "launch", simulator, "com.apple.DocumentsApp"], check=True)
groups = subprocess.check_output(
    ["xcrun", "simctl", "get_app_container", simulator, "com.apple.DocumentsApp", "groups"], text=True)
row = next(line for line in groups.splitlines() if "group.com.apple.FileProvider.LocalStorage" in line)
match = re.search(r"(/.*)$", row)
if not match:
    raise RuntimeError("Files LocalStorage container path was not returned")
folder = Path(match.group(1).strip()) / "File Provider Storage" / "Tayya-test-files"
folder.mkdir(parents=True, exist_ok=True)
writer = Path("Generated/FilesFixtureWriter").resolve()
writer.parent.mkdir(parents=True, exist_ok=True)
sdk = subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], text=True).strip()
subprocess.run(["xcrun", "--sdk", "iphonesimulator", "swiftc",
    "-target", platform.machine() + "-apple-ios17.0-simulator",
    "-sdk", sdk, "Tools/FilesFixtureWriter.swift", "-o", str(writer)], check=True)
for name, target in [("english.pdf", "Picker-fixture.pdf"), ("office-demo.pptx", "Picker-office.pptx")]:
    sources = list(Path("App").rglob(name))
    if len(sources) != 1:
        raise RuntimeError(f"Expected one fixture: {name}")
    source = sources[0]
    destination = folder / target
    # Host-side rsync can leave Files' first document ID absent from the iOS
    # provider database. Coordinate creation and a read inside the simulator.
    subprocess.run(["xcrun", "simctl", "spawn", simulator, str(writer),
        str(source.resolve()), str(folder), target], check=True)
    if hashlib.sha256(source.read_bytes()).digest() != hashlib.sha256(destination.read_bytes()).digest():
        raise RuntimeError(f"Fixture bytes differ: {name}")
    print(f"External Files fixture ready: {target} ({destination.stat().st_size} bytes)", flush=True)
