"""Copy saved CI margin drawings after XCTest; never modify app data."""
import base64
import hashlib
import json
import os
import subprocess
from pathlib import Path

def collect(app_root, output, max_drawings=32, max_bytes=2_000_000):
    app_root, output = Path(app_root).resolve(), Path(output)
    output.mkdir(parents=True, exist_ok=True)
    records, omitted = [], []
    retained_bytes = 0
    pages = list(app_root.glob("tmp/ReviewEntry-*/*-margins/*.json"))
    pages += list(app_root.glob("Documents/*-margins/*.json"))
    for page in sorted(pages):
        if page.is_symlink() or not page.resolve().is_relative_to(app_root):
            continue
        source = str(page.relative_to(app_root))
        try:
            if page.stat().st_size > 3_000_000:
                omitted.append({"source": source, "reason": "page evidence cap"})
                continue
            original = page.read_bytes()
            payload = json.loads(original)
            if not payload.get("ink"):
                continue
            raw = base64.b64decode(payload["ink"], validate=True)
            if len(records) >= max_drawings or len(raw) > max_bytes or retained_bytes + len(raw) > 8_000_000:
                omitted.append({"source": source, "reason": "evidence cap"})
                continue
            filename = f"{len(records):03d}.drawing"
            (output / filename).write_bytes(raw)
            retained_bytes += len(raw)
            records.append({"source": source, "drawing": filename,
                "modified_unix": page.stat().st_mtime,
                "source_sha256": hashlib.sha256(original).hexdigest(),
                "drawing_sha256": hashlib.sha256(raw).hexdigest(),
                "bytes": len(raw), "page_id": payload.get("id"),
                "width": payload.get("width"), "height": payload.get("height")})
        except (ValueError, TypeError, OSError) as error:
            omitted.append({"source": source, "reason": type(error).__name__})
    report = {"drawings": records, "omitted": omitted,
        "retained_bytes": retained_bytes,
        "limits": {"drawings": max_drawings, "bytes_per_drawing": max_bytes, "bytes_total": 8_000_000},
        "scope": "Saved Documents and temporary ReviewEntry margin pages; read-only after UI tests"}
    (output / "manifest.json").write_text(json.dumps(report, indent=2) + "\n")
    return report

if __name__ == "__main__":
    root = subprocess.check_output(["xcrun", "simctl", "get_app_container",
        os.environ["SIMULATOR_ID"], "com.ahmadalawi.hashiya", "data"], text=True).strip()
    report = collect(root, "Evidence/saved-drawings")
    print(json.dumps(report, indent=2))
    if not report["drawings"]:
        raise SystemExit("No actual saved review drawings were available; evidence is incomplete")
