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
              "scope": "One original case; Metal System Trace in the selected simulator device context",
              "limits": "Measurement can perturb timing. No repair, release qualification or physical-device proof.",
              "app_pid": None, "profiler_exit": None, "test_exit": None, "errors": []}
    profiler = None
    tests = None
    attach_enabled = True
    stop_requested = False
    observation_tail = ""
    try:
        with (output / "original-test.log").open("w") as test_log, (output / "profiler.log").open("w") as trace_log, \
                (output / "original-test.log").open("r", errors="replace") as observations:
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
                                "--device", report["device"],
                                "--attach", str(pid), "--time-limit", "360s",
                                "--window", "120s", "--no-prompt",
                                "--output", str(output / "OriginalInk.trace")],
                                stdout=trace_log, stderr=subprocess.STDOUT)
                        elif time.monotonic() > attach_deadline:
                            raise TimeoutError("Actual App PID unavailable within180s; no test retry")
                    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
                        # A profiler failure must not terminate or relaunch XCTest.
                        report["errors"].append(str(error))
                        attach_enabled = False
                observation_tail = (observation_tail + observations.read())[-4000:]
                marker = "NativeInkVisibility stage=AccessibilityType-CompactSplitInk; observer=screen-only; result="
                if profiler is not None and profiler.poll() is None and not stop_requested and marker in observation_tail:
                    # Stop after the existing observer returns, before the test's
                    # screenshots/AX diagnostics and eventual App termination.
                    # Never change the original XCTest action, wait or outcome.
                    native_log = (output / "profiler.log").read_text()
                    if "Stopping recording" not in native_log and "Saving output file" not in native_log:
                        profiler.send_signal(signal.SIGINT)
                    stop_requested = True
                    report["stop_reason"] = "Original Notes live-pixel observation completed"
                    report["stop_requested_utc"] = utc()
                if time.monotonic() > deadline:
                    raise TimeoutError("Original native test process exceeded600s; no retry")
                time.sleep(0.25)  # Process readiness only; no UI wait or test timing change.
            report["test_exit"] = tests.returncode
            report["test_completed_utc"] = utc()
            if profiler is None:
                raise RuntimeError("Original test ended before a verified actual App PID could be attached")
            if profiler.poll() is None and not stop_requested:
                native_log = (output / "profiler.log").read_text()
                if "Stopping recording" not in native_log and "Saving output file" not in native_log:
                    profiler.send_signal(signal.SIGINT)
                report["stop_reason"] = "Original test completed; preserve any native auto-save already running"
            # Native archive finalization is separate from the unchanged5s UI
            # contract. Poll while saving; never send another SIGINT during save.
            saving_deadline = time.monotonic() + 300
            heartbeat = time.monotonic() + 30
            while profiler.poll() is None and time.monotonic() < saving_deadline:
                if time.monotonic() >= heartbeat:
                    print("Original test completed; native trace finalization is still running", flush=True)
                    heartbeat = time.monotonic() + 30
                time.sleep(0.5)
            if profiler.poll() is None:
                profiler.kill()
                report["profiler_exit"] = profiler.wait(timeout=10)
                raise TimeoutError("Native trace finalization exceeded its separate300s resource ceiling")
            report["profiler_exit"] = profiler.returncode
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
        if report["profiler_exit"] not in (None, 0):
            report["profiler_error_tail"] = (output / "profiler.log").read_text()[-4000:]
        (output / "process-report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, indent=2))
    return report["test_exit"] or (2 if report["errors"] or report["profiler_exit"] != 0 or not report["trace_exists"] else 0)


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] != "xcodebuild":
        raise SystemExit("Provide the original xcodebuild test-without-building command")
    raise SystemExit(run(sys.argv[1:]))
