"""Index unmodified production screenshots using their native XCTest metadata."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import shutil


def png_orientation(data):
    """Read TIFF orientation from the original PNG eXIf chunk; change no pixels."""
    offset = 8
    while offset + 12 <= len(data):
        length = struct.unpack_from('>I', data, offset)[0]
        end = offset + 12 + length
        if end > len(data):
            raise ValueError('Truncated original PNG chunk')
        if data[offset + 4:offset + 8] == b'eXIf':
            tiff = data[offset + 8:offset + 8 + length]
            if tiff.startswith(b'Exif\x00\x00'):
                tiff = tiff[6:]
            if len(tiff) < 8 or tiff[:2] not in (b'MM', b'II'):
                raise ValueError('Invalid PNG orientation TIFF header')
            endian = '>' if tiff[:2] == b'MM' else '<'
            if struct.unpack_from(endian + 'H', tiff, 2)[0] != 42:
                raise ValueError('Invalid PNG orientation TIFF version')
            directory = struct.unpack_from(endian + 'I', tiff, 4)[0]
            if directory + 2 > len(tiff):
                raise ValueError('Invalid PNG orientation directory')
            count = struct.unpack_from(endian + 'H', tiff, directory)[0]
            if directory + 2 + count * 12 > len(tiff):
                raise ValueError('Truncated PNG orientation directory')
            for index in range(count):
                entry = directory + 2 + index * 12
                tag, kind, values = struct.unpack_from(endian + 'HHI', tiff, entry)
                if tag == 274:
                    value = struct.unpack_from(endian + 'H', tiff, entry + 8)[0]
                    if kind != 3 or values != 1 or value not in range(1, 9):
                        raise ValueError('Invalid PNG orientation value')
                    return value
            return 1
        offset = end
    return 1


def stage(summary, attachments, output, source, family, run):
    """Copy only raw production PNG/JSON evidence, excluding large xcresults."""
    if output.exists():
        raise ValueError("Existing capture evidence must not be overwritten")
    result = json.loads(summary.read_text())
    if result.get("result") != "Passed" or result.get("passedTests", 0) <= 0 or any(result.get(key, 0) for key in ("failedTests", "skippedTests", "expectedFailures")):
        raise ValueError("Only executed passing native captures may be staged")
    if not re.fullmatch(r"[0-9a-f]{40}", source) or family not in ("iPhone", "iPad") or int(run) <= 0:
        raise ValueError("Actual native provenance is required")
    manifest = json.loads((attachments / "manifest.json").read_text())
    retained, files = [], {}
    for test in manifest:
        selected = []
        for attachment in test.get("attachments", []):
            if not attachment.get("suggestedHumanReadableName", "").startswith(("ProductionScene-", "ProductionMetadata-")):
                continue
            name = attachment["exportedFileName"]
            original = (attachments / name).resolve()
            if not original.is_relative_to(attachments.resolve()) or not original.is_file():
                raise ValueError("Invalid native capture attachment")
            files[name] = original
            selected.append(attachment)
        if selected:
            retained.append(dict(test, attachments=selected))
    if not any(a.get("suggestedHumanReadableName", "").startswith("ProductionScene-") for t in retained for a in t["attachments"]):
        raise ValueError("No production screenshots were executed")
    destination = output / "Screenshots"
    destination.mkdir(parents=True)
    for name, original in files.items():
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(original, target)
    shutil.copy2(summary, output / "summary.json")
    (destination / "manifest.json").write_text(json.dumps(retained, ensure_ascii=False, indent=2))
    (output / "provenance.json").write_text(json.dumps(dict(source=source, family=family, run=int(run)), indent=2))
    return len(files)


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
            for field in ("screen", "orientation", "font_size", "color_mode", "language", "metadata_origin", "pixel_width", "pixel_height", "window_width", "window_height", "png_orientation"):
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
            if (width, height) != (row["pixel_width"], row["pixel_height"]):
                raise ValueError("Original PNG dimensions do not match native capture metadata")
            orientation = png_orientation(data)
            if orientation != row["png_orientation"]:
                raise ValueError("Original PNG orientation does not match native ImageIO metadata")
            display_width, display_height = (height, width) if orientation in (5, 6, 7, 8) else (width, height)
            if row["window_width"] <= 0 or row["window_height"] <= 0 or abs(display_width / display_height - row["window_width"] / row["window_height"]) > 0.02:
                raise ValueError("Original PNG does not match the native window aspect")
            row.update(display_pixel_width=display_width, display_pixel_height=display_height,
                       scene=row["screen"], family=family, source=source, device=device,
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
