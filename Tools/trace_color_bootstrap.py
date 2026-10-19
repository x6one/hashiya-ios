"""Read-only macOS launch diagnostics for the first native color-picker input.

The observer never launches a picker, changes the simulator, or retries input.
Run only on a macOS runner alongside the unchanged XCTest journey.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
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


def capture(process, output):
    pid = process["pid"]
    target = output / f"sample-{pid}.txt"
    result = {"pid": pid, "path": target.name,
              "requested_utc": datetime.now(timezone.utc).isoformat()}
    try:
        with (output / f"sample-{pid}-status.txt").open("w") as status:
            completed = subprocess.run(
                ["sudo", "-n", "sample", str(pid), "1", "1", "-file", str(target)],
                stdout=status, stderr=subprocess.STDOUT, timeout=15)
        result["exit_code"] = completed.returncode
    except subprocess.TimeoutExpired:
        # Symbol processing exceeded this bound in the real runner even though
        # the sample file was written. Keep it and continue other captures.
        result["timed_out"] = True
    result["finished_utc"] = datetime.now(timezone.utc).isoformat()
    result["file_exists"] = target.exists()
    return result


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
        # Resolve stable host PIDs during build, so a slow ps/symbol lookup
        # cannot postpone both launch-broker samples until after the input.
        hosts = [p for p in selected_processes()
                 if "ColorPickerUIService" not in p["command"]][:4]
        record["host_processes_before_test"] = hosts
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
                with ThreadPoolExecutor(max_workers=6) as workers:
                    pending = [workers.submit(capture, process, output) for process in hosts]
                    processes = selected_processes()
                    record["processes_at_input"] = processes
                    known = {p["pid"] for p in hosts}
                    children = [p for p in processes if p["pid"] not in known][:2]
                    pending.extend(workers.submit(capture, process, output) for process in children)
                    record["samples"] = [item.result() for item in pending]
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
