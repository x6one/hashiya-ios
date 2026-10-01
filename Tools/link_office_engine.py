"""Link the packaged COKit API and static service factories for an iOS device.

This is a linkage gate, not a device runtime test. No simulator substitute is
used and the resulting executable is never presented as an installable app.
"""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path


def link(candidate: Path, output: Path) -> None:
    candidate = candidate.resolve(strict=True)
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((candidate / "manifest.json").read_text())
    binaries = []
    for record in manifest["inputs"]:
        binary = (candidate / record["path"]).resolve(strict=True)
        if not binary.is_relative_to(candidate):
            raise ValueError("Link input escaped the candidate")
        with binary.open("rb") as file:
            digest = hashlib.file_digest(file, "sha256").hexdigest()
        if digest != record["sha256"]:
            raise ValueError(f"Link input hash changed: {binary.name}")
        binaries.append(str(binary))
    filelist = output / "engine-filelist.txt"
    filelist.write_text("\n".join(binaries) + "\n")
    source = output / "probe.mm"
    source.write_text('''#include <COKit/COKitInit.h>
extern "C" {
#include "native-code.h"
}
// These references force the real bootstrap, document loading and PDF export
// APIs into the executable. This file is linked but cannot run on macOS.
int main(int argc, char **argv) {
    if (argc < 3) return 2;
    auto *office = cok_init_2(nullptr, nullptr);
    if (!office) return 3;
    auto *document = office->documentLoadWithOptions(argv[1], "Language=en-US");
    if (!document) return 4;
    const bool saved = document->saveAs(argv[2], "pdf", nullptr);
    delete document;
    return saved ? 0 : 5;
}
''')
    sdk = subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"], text=True).strip()
    executable = output / "OfficeEngineProbe"
    command = ["xcrun", "--sdk", "iphoneos", "clang++", "-target", "arm64-apple-ios17.0",
               "-isysroot", sdk, "-std=c++20", "-DIOS=1", "-DDISABLE_DYNLOADING=1",
               "-I" + str(candidate / "include"), "-I" + str(candidate), str(source),
               "-Wl,-filelist," + str(filelist), "-o", str(executable),
               "-framework", "UIKit", "-framework", "Foundation", "-framework", "CoreGraphics",
               "-framework", "CoreText", "-framework", "CoreFoundation", "-framework", "Security",
               "-framework", "SystemConfiguration", "-framework", "CoreServices",
               "-liconv", "-lz", "-lsqlite3", "-lbz2", "-lxml2", "-lresolv"]
    subprocess.run(command, check=True)
    subprocess.run(["xcrun", "lipo", str(executable), "-verify_arch", "arm64"], check=True)
    details = subprocess.check_output(["xcrun", "vtool", "-show-build", str(executable)], text=True)
    if "platform IOS\n" not in details:
        raise ValueError("The linker probe did not target iOS devices")
    (output / "link-report.json").write_text(json.dumps({"source": manifest["source"],
        "architecture": "arm64", "platform": "iphoneos", "linked": True,
        "runtime_tested": False, "build_commands": details}, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    link(args.candidate, args.output)
