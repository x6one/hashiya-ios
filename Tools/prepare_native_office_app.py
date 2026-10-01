"""Generate the experimental device app project from a verified engine package.

The ordinary project.yml remains the simulator/Quick Look build. This generated
spec enables the local converter only for the separately verified device build.
"""
import argparse
import json
from pathlib import Path
import yaml


def prepare(candidate: Path, report: Path, project: Path) -> Path:
    candidate = candidate.resolve(strict=True)
    report = report.resolve(strict=True)
    manifest = json.loads((candidate / "manifest.json").read_text())
    verification = json.loads((report / "link-report.json").read_text())
    if not verification["linked"] or verification["source"] != manifest["source"]:
        raise ValueError("The engine package has not passed linkage")
    spec = yaml.safe_load(project.read_text())
    app = spec["targets"]["Hashiya"]
    app["sources"].append("NativeOffice")
    settings = app["settings"]["base"]
    settings.update({"SWIFT_OBJC_BRIDGING_HEADER": "NativeOffice/OfficeEngineBridge.h",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "$(inherited) HASHIYA_NATIVE_OFFICE",
        "GCC_PREPROCESSOR_DEFINITIONS": "$(inherited) IOS=1 DISABLE_DYNLOADING=1",
        "CLANG_CXX_LANGUAGE_STANDARD": "c++20",
        "HEADER_SEARCH_PATHS": [str(candidate / "include"), str(candidate)],
        "OTHER_LDFLAGS": "$(inherited) -filelist " + str(report / "engine-filelist.txt")
            + " -framework UIKit -framework Foundation -framework CoreGraphics -framework CoreText"
            + " -framework CoreFoundation -framework Security -framework SystemConfiguration -framework CoreServices"
            + " -liconv -lz -lsqlite3 -lbz2 -lxml2 -lresolv"})
    # Preserve engine directory topology: bootstrap resolves share/ and services/
    # relative to the app root. Xcode resource flattening would break it.
    quoted = lambda p: "'" + str(p).replace("'", "'\\''") + "'"
    app["postBuildScripts"] = [{"name": "Copy native Office resources and notices",
        "script": 'cp -R ' + quoted(candidate / "resources") + '/. "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/"\n'
            + 'mkdir -p "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/OfficeEngineNotices"\n'
            + 'cp ' + quoted(candidate) + '/COPYING* "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/OfficeEngineNotices/"\n'
            + 'cp ' + quoted(candidate / "manifest.json") + ' "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/OfficeEngineNotices/engine-manifest.json"\n'
            + 'if [ -d ' + quoted(candidate / "notices") + ' ]; then cp -R ' + quoted(candidate / "notices")
            + '/. "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/OfficeEngineNotices/"; fi\n',
        "basedOnDependencyAnalysis": False}]
    spec["settings"]["base"]["MARKETING_VERSION"] = "0.2.4"
    spec["settings"]["base"]["CURRENT_PROJECT_VERSION"] = "6"
    output = project.with_name("NativeOfficeProject.yml")
    output.write_text(json.dumps(spec, indent=2) + "\n")
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("report", type=Path)
    parser.add_argument("project", type=Path)
    args = parser.parse_args()
    print(prepare(args.candidate, args.report, args.project))
