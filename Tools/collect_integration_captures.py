"""Index unmodified production screenshots using their native XCTest metadata."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct


def collect(evidence, source, family, run, job):
    if not re.fullmatch(r"[0-9a-f]{40}", source) or family not in ("iPhone", "iPad"):
        raise ValueError("Exact source SHA and device family are required")
    if int(run) <= 0 or int(job) <= 0:
        raise ValueError("Actual Actions run and job IDs are required")
    summary = json.loads((evidence / "summary.json").read_text())
    if summary["result"] != "Passed" or any(summary.get(key, 0) for key in ("failedTests", "skippedTests", "expectedFailures")):
        raise ValueError("Failed or skipped native verification cannot become an approved review")
    if summary.get("passedTests", 0) <= 0:
        raise ValueError("No executed native tests")
    screenshots = evidence / "Screenshots"
    manifest = json.loads((screenshots / "manifest.json").read_text())

    def path(attachment):
        name = attachment["exportedFileName"]
        target = (screenshots / name).resolve()
        if not target.is_relative_to(screenshots.resolve()):
            raise ValueError("Attachment path escapes evidence directory")
        return target

    records = []
    for test in manifest:
        attachments = test.get("attachments", [])
        native = {}
        for attachment in attachments:
            if not attachment.get("suggestedHumanReadableName", "").startswith("ProductionMetadata-"):
                continue
            details = json.loads(path(attachment).read_text())
            for field in ("screen", "orientation", "font_size", "color_mode", "language", "metadata_origin"):
                if not details.get(field):
                    raise ValueError("Incomplete native capture metadata: " + field)
            key = details["screen"] + "-" + details["orientation"]
            if key in native:
                raise ValueError("Ambiguous native metadata within one test: " + key)
            native[key] = details
        for attachment in attachments:
            name = attachment.get("suggestedHumanReadableName", "")
            if not name.startswith("ProductionScene-"):
                continue
            matches = [key for key in native if name.startswith("ProductionScene-" + key + "_") or name == "ProductionScene-" + key + ".png"]
            if len(matches) != 1:
                raise ValueError("Screenshot requires its own native metadata: " + name)
            device = attachment.get("deviceName", "")
            if not device.startswith(family):
                raise ValueError("Screenshot device does not match the requested family")
            original = path(attachment)
            data = original.read_bytes()
            if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
                raise ValueError("Native screenshot must be the original PNG")
            width, height = struct.unpack(">II", data[16:24])
            row = dict(native[matches[0]])
            row.update(scene=row["screen"], family=family, source=source, device=device,
                       test=test["testIdentifier"],
                       test_url=f"https://github.com/x6one/hashiya-ios/actions/runs/{int(run)}/job/{int(job)}",
                       file=original.relative_to(evidence.resolve()).as_posix(),
                       sha256=hashlib.sha256(data).hexdigest(), png_width=width, png_height=height)
            records.append(row)
    if not records:
        raise ValueError("No executed production captures found")
    return records


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--family", required=True)
    parser.add_argument("--run", type=int, required=True)
    parser.add_argument("--job", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    records = collect(args.evidence, args.source, args.family, args.run, args.job)
    args.output.write_text(json.dumps(records, ensure_ascii=False, indent=2))
    print("Indexed original native captures:", len(records))
