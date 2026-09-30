"""Retain a successful device-engine build for the next linking experiment.

This creates a development artifact, not a usable app or an XCFramework.
Requires the completed, pinned upstream iOS build and macOS's lipo verifier.
"""
import argparse
import glob
import hashlib
import json
import shutil
import subprocess
import tarfile
from pathlib import Path


def package(engine: Path, output: Path) -> Path:
    engine = engine.resolve(strict=True)
    output = output.resolve()
    if output.exists():
        raise ValueError("Use a new output directory; never replace an earlier build")
    if output.is_relative_to(engine):
        raise ValueError("Output must be outside the engine source tree")
    generated = engine / "workdir/CustomTarget/ios"
    manifest = generated / "ios-all-static-libs.list"
    resources = generated / "resources"
    for required in [manifest, resources / "fundamentalrc", resources / "services.rdb",
                     engine / "include/COKit/COKit.hxx", engine / "include/COKit/COKitInit.h"]:
        if not required.is_file():
            raise ValueError(f"Incomplete engine build: {required.name}")
    binaries = set()
    for pattern in manifest.read_text().splitlines():
        pattern = pattern.strip()
        if not pattern:
            continue
        if not Path(pattern).is_absolute():
            pattern = str(engine / pattern)
        matches = glob.glob(pattern)
        if not matches and not glob.has_magic(pattern):
            raise ValueError(f"Required linker input is missing: {pattern}")
        for match in matches:
            binary = Path(match).resolve(strict=True)
            if not binary.is_relative_to(engine) or binary.suffix not in {".a", ".o"}:
                raise ValueError("Linker input must be an archive/object inside the engine tree")
            binaries.add(binary)
    if not binaries:
        raise ValueError("Empty native linker manifest")
    # Do not silently retain macOS or simulator libraries as device libraries.
    for binary in sorted(binaries):
        subprocess.run(["xcrun", "lipo", "-verify_arch", "arm64", str(binary)], check=True)
    source = subprocess.check_output(["git", "-C", str(engine), "rev-parse", "HEAD"], text=True).strip()
    output.mkdir(parents=True)
    records = []
    for binary in sorted(binaries):
        relative = binary.relative_to(engine)
        target = output / "link-inputs" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(binary, target)
        records.append({"path": target.relative_to(output).as_posix(), "bytes": target.stat().st_size,
                        "sha256": hashlib.file_digest(target.open("rb"), "sha256").hexdigest()})
    shutil.copytree(resources, output / "resources")
    shutil.copytree(engine / "include/COKit", output / "include/COKit")
    shutil.copy2(generated / "native-code.h", output / "native-code.h")
    for pattern in ["COPYING*", "LICENSE*", "README.license"]:
        for path in engine.glob(pattern):
            if path.is_file():
                shutil.copy2(path, output / path.name)
    (output / "manifest.json").write_text(json.dumps({"source": source, "platform": "iphoneos",
        "architecture": "arm64", "inputs": records}, indent=2) + "\n")
    (output / "README.txt").write_text("Internal arm64 device-engine linking candidate.\n"
        "Not an IPA, not an XCFramework, not runtime-validated.\n"
        "Resources, bootstrap/service factories, system frameworks and COKit initialization still need integration.\n"
        "Preserve all upstream and dependency notices before distributing an application.\n"
        f"Official source: https://github.com/CollaboraOnline/online.mirror/tree/{source}\n")
    archive = output.with_suffix(".tar.gz")
    with tarfile.open(archive, "w:gz", compresslevel=3) as tar:
        tar.add(output, arcname=output.name)
    return archive


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("engine", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(package(args.engine, args.output))
