"""One original real-App test, one host Metal trace; never retry or repair the UI.

macOS runner only. No app container writes, credentials or user-library reads.
The profiler changes measurement conditions; a pass does not resolve the defect.
"""
import datetime
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def actual_app_pid(device):
    result = subprocess.run(["pgrep", "-x", "Hashiya"], capture_output=True, text=True, check=False)
    if result.returncode not in (0, 1):
        raise RuntimeError("Cannot enumerate the actual simulator App process")
    matches = []
    for value in result.stdout.split():
        pid = int(value)
        command = subprocess.run(["ps", "-p", str(pid), "-o", "comm="],
                                 capture_output=True, text=True, check=False)
        path = command.stdout.strip()
        if device.lower() in path.lower() and path.endswith("/Hashiya.app/Hashiya"):
            matches.append(pid)
    if len(matches) > 1:
        raise RuntimeError("More than one real App process belongs to the selected simulator")
    return matches[0] if matches else None


def run(command):
    output = Path("NativeGPUTrace")
    output.mkdir(exist_ok=True)
    report = {"source": os.environ["GITHUB_SHA"], "run": os.environ["GITHUB_RUN_ID"],
              "device": os.environ["SIMULATOR_ID"], "started_utc": utc(),
              "target": "HashiyaUITests/LaunchTests/testIndividualInkTargetsAtAccessibilityTextSize",
              "scope": "One original case; host Metal System Trace of actual simulator App PID",
              "limits": "Measurement can perturb timing. No repair, release qualification or physical-device proof.",
              "app_pid": None, "profiler_exit": None, "test_exit": None, "errors": []}
    profiler = None
    tests = None
    attach_enabled = True
    try:
        with (output / "original-test.log").open("w") as test_log, (output / "profiler.log").open("w") as trace_log:
            tests = subprocess.Popen(command, stdout=test_log, stderr=subprocess.STDOUT)
            deadline = time.monotonic() + 600
            attach_deadline = time.monotonic() + 180
            while tests.poll() is None:
                if profiler is None and attach_enabled:
                    try:
                        pid = actual_app_pid(report["device"])
                        if pid is not None:
                            report["app_pid"] = pid
                            report["attach_requested_utc"] = utc()
                            profiler = subprocess.Popen([
                                "xcrun", "xctrace", "record", "--template", "Metal System Trace",
                                "--attach", str(pid), "--time-limit", "360s",
                                "--output", str(output / "OriginalInk.trace")],
                                stdout=trace_log, stderr=subprocess.STDOUT)
                        elif time.monotonic() > attach_deadline:
                            raise TimeoutError("Actual App PID unavailable within180s; no test retry")
                    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
                        # A profiler failure must not terminate or relaunch XCTest.
                        report["errors"].append(str(error))
                        attach_enabled = False
                if time.monotonic() > deadline:
                    raise TimeoutError("Original native test process exceeded600s; no retry")
                time.sleep(0.25)  # Process readiness only; no UI wait or test timing change.
            report["test_exit"] = tests.returncode
            report["test_completed_utc"] = utc()
            if profiler is None:
                raise RuntimeError("Original test ended before a verified actual App PID could be attached")
            if profiler.poll() is None:
                profiler.send_signal(signal.SIGINT)
            try:
                report["profiler_exit"] = profiler.wait(timeout=60)
            except subprocess.TimeoutExpired:
                profiler.kill()
                report["profiler_exit"] = profiler.wait(timeout=10)
                raise TimeoutError("Profiler did not finalize within60s after original-case completion")
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        report["errors"].append(str(error))
    finally:
        for process in (tests, profiler):
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=10)
        if tests is not None:
            report["test_exit"] = tests.returncode
        if profiler is not None:
            report["profiler_exit"] = profiler.returncode
        report["completed_utc"] = utc()
        report["trace_exists"] = (output / "OriginalInk.trace").exists()
        (output / "process-report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, indent=2))
    return report["test_exit"] or (2 if report["errors"] or report["profiler_exit"] != 0 or not report["trace_exists"] else 0)


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] != "xcodebuild":
        raise SystemExit("Provide the original xcodebuild test-without-building command")
    raise SystemExit(run(sys.argv[1:]))
