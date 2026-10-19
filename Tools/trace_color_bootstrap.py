"""Read-only macOS launch diagnostics for the first native color-picker input.

The observer never launches a picker, changes the simulator, or retries input.
Run only on a macOS runner alongside the unchanged XCTest journey.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import signal
import subprocess
import time


def selected_processes():
    rows = subprocess.check_output(
        ["ps", "-axo", "pid=,ppid=,etime=,pcpu=,stat=,comm="], text=True)
    selected = []
    for row in rows.splitlines():
        fields = row.strip().split(None, 5)
        if len(fields) != 6:
            continue
        pid, parent, elapsed, cpu, state, command = fields
        if any(name in command for name in (
                "launchd_sim", "CoreSimulatorService", "ColorPickerUIService")):
            selected.append({"pid": int(pid), "parent": int(parent),
                             "elapsed": elapsed, "cpu": cpu,
                             "state": state, "command": command})
    return selected


def observe(build_log, output):
    output.mkdir(parents=True, exist_ok=True)
    record = {"started_utc": datetime.now(timezone.utc).isoformat(),
              "source_mutated": False, "triggered": False, "samples": []}
    host_file = (output / "host-color-launch.log").open("w")
    predicate = 'eventMessage CONTAINS[c] "ColorPicker"'
    stream = subprocess.Popen(["log", "stream", "--style", "compact", "--level",
                               "debug", "--predicate", predicate],
                              stdout=host_file, stderr=subprocess.STDOUT)
    try:
        deadline = time.monotonic() + 1200
        marker = 'Waiting 5.0s for "nativeInkColorPicker"'
        while time.monotonic() < deadline:
            tail = ""
            if build_log.exists():
                with build_log.open("rb") as current:
                    current.seek(max(0, build_log.stat().st_size - 32768))
                    tail = current.read().decode(errors="replace")
            if marker in tail:
                record["triggered"] = True
                record["trigger_utc"] = datetime.now(timezone.utc).isoformat()
                # Capture both the host launch broker and a child that has
                # acquired a PID but may still be executing dyld/initializers.
                processes = selected_processes()
                record["processes_at_input"] = processes
                for process in processes[:6]:
                    pid = process["pid"]
                    target = output / f"sample-{pid}.txt"
                    with (output / f"sample-{pid}-status.txt").open("w") as status:
                        result = subprocess.run(
                            ["sudo", "-n", "sample", str(pid), "1", "1", "-file", str(target)],
                            stdout=status, stderr=subprocess.STDOUT, timeout=15)
                    record["samples"].append({"pid": pid, "exit_code": result.returncode,
                                               "path": target.name})
                record["processes_after_samples"] = selected_processes()
                break
            # Poll the test log only. This does not delay any application input
            # or alter an XCTest readiness guard or execution-time allowance.
            time.sleep(0.2)
    finally:
        record["finished_utc"] = datetime.now(timezone.utc).isoformat()
        (output / "observer.json").write_text(json.dumps(record, indent=2) + "\n")
        if stream.poll() is None:
            stream.terminate()
        try:
            stream.wait(timeout=5)
        except subprocess.TimeoutExpired:
            stream.kill()
            stream.wait()
        host_file.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-log", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    def stop_observing(_signum, _frame):
        raise SystemExit(0)
    signal.signal(signal.SIGTERM, stop_observing)
    observe(args.build_log, args.output)
