# Tayya native GPU trace plan

> **For agentic workers:** Use superpowers:executing-plans inline. No production repair is authorized by a passing diagnostic alone.

**Goal:** Measure the previously unobserved native command-submission/execution boundary in the original real-App iPad live-ink case.

**Architecture:** Attach the existing Xcode Metal System Trace instrument to the actual simulator App host PID. Preserve the unmodified original XCTest, original PNGs, xcresult, native logs and trace. Do not substitute an isolated canvas or a rendering-completion callback: the latter was already investigated and is not an interactive-stroke revision oracle.

**Tech Stack:** Existing macOS15 runner, Xcode26.2, xctrace, Python standard library, XCTest.

**Spec:** User's current App Store request and `Verification/Diagnostics/store-publication-current.json`, especially full9fd1/run40402135051 and the inconclusive94dcc pair. Store-side `cb4f7e62eecf45292d3e604dc542c1b496479031` preserves the completed native-log comparison.

## Global constraints

- App0.6.0 Build13, com.ahmadalawi.hashiya, iOS17 minimum, iPhone+iPad unchanged.
- No App/UITest edits, altered assertion, timeout extension, automatic retry, full gate, signing or Apple write in this diagnostic.
- One original `LaunchTests.testIndividualInkTargetsAtAccessibilityTextSize` on fresh iPad13M5/iOS26.2; original worker default, no thumbnail-thread probe flag.
- No new package or paid tool. Existing isolated integration/tayya-app-store worktree; stable and Store controller unchanged.
- Failed case remains failed even if evidence collection succeeds. A passed case or profiler attachment failure does not establish a repair.

## Review focus

- Wrong process: require a single Hashiya host PID, whose executable belongs to the selected simulator and ends with Hashiya.app/Hashiya; never attach XCTestRunner or a host service.
- Profiler missing/permissions: inspect templates before testing; keep profiler status separate from original test status. Do not silently fall back or rerun.
- App exits while attaching: save the precise record error, PID and return codes; preserve original xcresult.
- Empty trace: retain table of contents and exported Metal/GPU table rows; do not infer healthy rendering from file existence.
- Measurement effect: profiler can alter timing. Neither a healthy trace nor CPU/GPU timings from another process prove this intermittent defect fixed.

## Task1: One real native trace

Files: create `Tools/profile_native_ink.py`, `Tools/test_profile_native_ink.py` and `.github/workflows/tayya-native-gpu-trace.yml`; no application files.

- [x] Validate workflow with installed actionlint, Python AST and existing Tools contracts. Confirm App, UITests, NativeOffice, project and release workflows are byte-identical to93ec4f9.
- [ ] Build for testing on macOS, then execute only the original targeted case while attaching Metal System Trace once to the verified actual App PID.
- [ ] Stop/finalize the profiler on original-case completion; preserve independent exit codes and exact source/run. Export available native Metal/GPU schemas through xctrace, retain originals.
- [ ] Inspect actual test failure/PNG/trace coverage before making any causal statement. A failed profiler is infrastructure evidence, not an App failure. A passed case is inconclusive.
- [ ] Record factual result and request one focused final review of this diagnostic, without a full-branch reanalysis or automatic new test run.

## Ruling

Prior user authorization supplies execution approval: do not pause for routine plan confirmation. This is diagnostic infrastructure around an already-failed original test, not production behavior implementation; no fabricated RED/GREEN repair claim. Apple documents Metal System Trace and CLI trace export; GPU capture is not assumed unavailable on Simulator. No native callback counters are reintroduced.

References: https://developer.apple.com/videos/play/wwdc2023/10099/ ; https://developer.apple.com/documentation/xcode-release-notes/xcode-12-release-notes/ ; https://developer.apple.com/documentation/metal/developing-metal-apps-that-run-in-simulator .
