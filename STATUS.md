# Tayya 0.6.0 (13) — rescue checkpoint, 2026-10-19 UTC

Release remains blocked pending final-source gates. No accepted IPA, PR merge or Apple upload. Bundle ID: `com.ahmadalawi.hashiya`.

## Verified targeted repair

[Run39189664681](https://github.com/x6one/hashiya-ios/actions/runs/39189664681), source `756ddd773c9881319adbf22eba664e64650b4b6d`: Tools14 pass; iPhone Accessibility3/3, Standard ink and navigation pass; iPad Accessibility, Standard ink and navigation pass. Eight native executions, zero failures. All original assertions/input/case deadlines retained.

Actual callback records match the tested phone rail and occur inside two captured drags: inherited cancellation0 → owned cancellation1 while the tool button tracks; native offset0→50. This verifies the intervention. The original inherited-policy handoff race is strongly supported; original callback invocation and all hosting-layout effects were not independently isolated. [Evidence and limitations](Verification/Diagnostics/rail-cancellation-39189664681.json).

Only the InkToolbar scroll holder changes. Its HStack/actions/picker/style are retained. Navigation policy, normal touch delivery, PencilKit and storage are unchanged. Effective compact width/content width match baseline. Natural Accessibility intrinsic height49.667 vs48 is documented; actual screenshots show usable targets and visible ink. No speculative height clamp is added.

The rejected delayed-touch-delivery experiment remains reverted. [Its report](Verification/Diagnostics/rail-delivery-39186654628.json). [Original failure capture](Verification/Diagnostics/rail-tracking-39187892547.json).

## Current integration result

Source `f2c376b7651c5d62bd92b49dc0cbdd3168a93910`, [run39277996098](https://github.com/x6one/hashiya-ios/actions/runs/39277996098): Stage A14 Tools/syntax/lint pass. Phone B4/5: both ink cases, document post-reopen Undo/Redo and navigation pass; the added margin fresh-stroke check fails321. Phone full C is not reached. iPad remains running.

The added test input is invalid on the phone's fitted page: actual synthesized startx132 is outside paperx178.713–261.287. Old ink/count1 remain visible. [Exact screenshot/event evidence](Verification/Diagnostics/reopen-geometry-39277996098.json). This is a test-calibration error, not proven drawing loss. All original assertions/case deadlines remain.

Isolated correction `4c599d16dc8fc4b668f2a9154c8d1ef6548285bd`, [run39281549900](https://github.com/x6one/hashiya-ios/actions/runs/39281549900), tests the same existing phone margin case once with a centered vertical stroke inside the fitted paper. Production code and document gesture are unchanged. Targeted result pending; no unchanged retry or full rerun started.

## Final-source verification now required

The integration contains the bounded rail repair, public font resources for newly generated guide PDFs, Files fixture foreground cleanup, and equivalent single-query picker dismissal. A deliberate85% Back input replaces the previously cancelled65% test input; this is test calibration, not a claimed navigation production repair.

All32 original UI cases and224 original assertion lines remain. Two existing document/margin relaunch cases add a fresh stroke→Undo→Redo check. This does not assert persistence of prior-session undo history. Final verification removes the read-only CF/nav capture instrumentation by retaining the original PDFWorkspace source.

The pipeline runs Tools/lint, five relevant existing UI cases, then a fresh same-runtime simulator for full68 XCTest (all67 originals plus font regression)/32 XCUITest, exported bytes, three Maestro flows and real captures per family. Native Office build/package follows successful family jobs. Every final gate must reference the same source SHA. These final-source results are pending.

Full native Office build is not runtime conversion proof: the current hosted path builds an unsigned iphoneos binary and has no configured provisioned physical-device destination for Word/Excel conversion. Record this as unverified; do not substitute simulator/host checks.

An unsigned IPA needs valid signing. No merge into main or Apple upload is authorized by this checkpoint.

## Preserved history

[Previous checkpoint](docs/history/STATUS-before-rail-cancellation-2026-10-19.md), [original status](docs/history/STATUS-before-rescue-2026-10-19.md), and [original verification](Verification/Diagnostics/0.6.0-13-before-rescue-2026-10-19.json) remain unchanged. Earlier partial diagnostics do not qualify the release.
