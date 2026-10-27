# Tayya ink input boundary plan

> **For agentic workers:** Use superpowers:executing-plans inline. One targeted measurement, not a production repair or release gate.

**Goal:** Distinguish actual touch delivery, shared Undo Button activation, and Notes/PDF action routing in the failed original iPad case.

**Architecture:** Reuse the existing opt-in `NotesDockInputTrace` window-event recorder. Add scalar receipts at the shared Button and both existing destinations, preserving original action calls exactly once. All App additions are DEBUG-only. Enable the existing recorder for one original case through a test-runner environment variable; no Metal/System Trace or new observer/recognizer/view.

**Tech Stack:** Existing SwiftUI/UIKit, XCTest, Xcode26.2, GitHub Actions macOS, SwiftLint/SwiftFormat.

**Spec:** User request `/workspace/attachments/e5f58d12-be35-4499-9646-b699e5b6d859/Pasted text.txt`; actual evidence in Storebd126092c6b812c3ad2df9adecdd950e22d57b33 `Verification/Diagnostics/native-gpu-trace-current.json`.

## Global constraints

- Preserve0.6.0, com.ahmadalawi.hashiya, iOS17 minimum, iPhone+iPad, original152-case inventory and all original assertions/deadlines.
- No GPU Trace restart, sleep, timeout extension, extra press, source rollback, user-data/format change, full gate, signing or Apple write in this measurement.
- One original iPad `LaunchTests.testIndividualInkTargetsAtAccessibilityTextSize` via existing ink-screen-observer suite; no retry. A pass is inconclusive, not a repair.
- Keep the older live-pixel failure separate from the instrumented Undo failure. No common-cause assumption.
- Later release steps remain gated; user authorizes a higher Build only if13 was already used at Apple. No Apple review submission/public release.

## Evidence and hypothesis

Saved f6 XCTest session, decoded locally without a new run, records Undo down/up
at physical portrait point81.5,250 with0.05s contact, matching logical250,950.5
inside the recorded44pt target after landscape conversion. AppPID16500 sends a
TouchEventsCompleted acknowledgement. Redo has the corresponding81.5,300 point
and acknowledgement. These facts do not identify the receiving view, gesture
cancellation, Button activation or routing destination. Notes Undo action
receipts are absent, later Redo receipts exist, and native history is available.
The unchanged finalPDF1 stroke does not support accidental document Undo.

One falsifiable hypothesis is that the valid edge event fails activation or
is routed to a different destination. The existing recorder can measure the
missing event boundary; this is not a hypothesis that UndoManager lost history.
The older live0/saved2/raster3878 failure remains independently unresolved.

## Review focus

- Trace must be opt-in and compiled out of Release; original actions forward exactly once.
- Contact0/async activation must remain unmatched, not falsely assigned to a stale finger.
- Missing/truncated events and disabled probe must be reported, not read as no action.
- Original native test failure and skip counts remain authoritative; green diagnostics cannot qualify the release.
- Recorder can affect timing. Stop after one inconclusive/failed setup; no calibration loop.

## Task1: Measure the existing input boundary once

Files: App/NotesDockInputProbe.swift, App/MarginNotebook.swift,
App/PDFWorkspace.swift, UITests/LaunchTests.swift,
.github/workflows/tayya-integration.yml. No storage/model logic changes.

- [x] Add kind11 receipts, a=1Undo/2Redo, b=0Button/1Notes/2PDF, using the existing bounded/deferred recorder. Call before original Button activation and both destination entries, all DEBUG-only.
- [x] Add opt-in `TAYYA_INK_INPUT_PROBE=1` runner-to-launch-argument bridge. Existing suite still selects exactly the original one iPad case.
- [x] Validate Release-normalized source equality, unchanged assertions and test inventory, workflow/actionlint/embedded Python, existing40Tools contracts. Review the small diff before native execution.
- [ ] Execute once. Preserve original xcresult/PNGs and a small independent input-log/summary artifact. Require actual installed recorder and unskipped original case; preserve failures.
- [ ] Inspect actual point/view/gesture/activation/destination sequence. If a defect is proved, write the smallest deterministic regression before changing production behavior. Otherwise preserve exact blocker and stop; do not run the full gate or call a passing measurement a fix.

## Ruling

User already authorizes routine execution. Reusing this recorder measures a new
boundary supported by saved evidence; it is not a fourth GPU collector attempt.
No production repair is claimed. Existing original failure supplies the
behavioral RED; diagnostic receipts alone do not provide a RED/GREEN repair.
