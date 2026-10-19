# Tayya 0.6.0 (13) — rescue checkpoint, 2026-10-19 UTC

Release remains blocked pending final-source gates. No accepted IPA, PR merge or Apple upload. Bundle ID: `com.ahmadalawi.hashiya`.

## Current rescue qualification — 2026-10-19 UTC

Latest original full baseline is `df4ab1ddb7d5110eebf32a41ba00798098fda080`, [run39286829941](https://github.com/x6one/hashiya-ios/actions/runs/39286829941): both families68 XCTest pass; phone32 UI pass; iPad31 UI pass/1 case fail. Phone Maestro3 failed. No accepted IPA.

The original Maestro recording screenshot and both later Welcome screenshots show the same unanswered system microphone prompt. Explicit microphone permission in the shared test launch preserves every original assertion and the denial journey. Targeted [iPhone39321182827](https://github.com/x6one/hashiya-ios/actions/runs/39321182827), source `a0d6f35e44618eb3b3482a314a922b480d5fddac`:3/3 pass. [iPad39323494599](https://github.com/x6one/hashiya-ios/actions/runs/39323494599), source `21983ff8a8e9e806a1d313af3a07a7cf4c2bd431`:3/3 pass. Actual JUnit reports have zero failures/skips; archive SHA256/CRC and all three completion images per family reviewed.

The first cold iPad Maestro driver failed before any flow: server readiness appeared142s after start, after the client's deadline. The focused harness bounds that infrastructure readiness at180s; the same measured bound now applies to the full Maestro step; application assertions and native case limits are unchanged. The subsequent iPad pass is not independent proof it would itself exceed the earlier deadline.

Original failed iPad creation stored `Handwriting stages2445814` while the test searched `Handwriting stages24458143`; actual AX and video show the created card. Test submission now waits for the exact full text-field value. [Targeted39326353988](https://github.com/x6one/hashiya-ios/actions/runs/39326353988), source `533b63391be4f96839f2d55cc11552e9005307b7`:1/1 pass82.140s. Full input and persisted `library.json` agree on `Handwriting stages DCBC847E`; native counts1→2→3→4 and visible ink pass split, resize, rotation and expansion. All four actual screenshots and the saved3650-byte drawing reviewed. This is input/submission readiness evidence, not deterministic isolation of the native typing internals.

The first full candidate `b31d34472cbe17c0c13a97e6d2726bb41c816d7a`, [run39327688794](https://github.com/x6one/hashiya-ios/actions/runs/39327688794), stopped twice at the phone color prerequisite. Saved UI/video and OS logs prove a real blank native sheet: the OS color service finished bootstrap43.360s and20.665s after its request, after the original content guard had failed. Files setup and three-case selection also passed controlled probes; neither alone is a sufficient cause. The test now observes OS process startup with a measured60s bound, then applies the original5s content checks. It never launches or prewarms that service. [Target39340814240](https://github.com/x6one/hashiya-ios/actions/runs/39340814240), source `add7a22e739a0709cbbf4ec945fe4520c7c76527`:1/1 pass152.265s, zero failures/skips. Both actual picker images and archive SHA256/CRC reviewed. The process API reported runningForeground in both contexts; slow startup did not recur on this repair host. No claim that OS launch performance was repaired.

No production source was changed in this rescue qualification; the verified ink rail repair remains intact. All32 original UI case names and drawing assertions remain. [Concise evidence ledger](Verification/Diagnostics/lifecycle-rescue-2026-10-19.json).

After the targeted readiness pass, one complete gate is required on the final candidate SHA: original ink/navigation regressions, then68 XCTest/32 XCUITest, exported bytes, Maestro3 and real captures per family, followed by the existing native Office iphoneos build/package. Distinct targeted SHAs do not qualify the release. No merge or Apple upload. Physical-device Word/Excel conversion remains unverified. An unsigned IPA needs valid signing.

## Verified targeted repair

[Run39189664681](https://github.com/x6one/hashiya-ios/actions/runs/39189664681), source `756ddd773c9881319adbf22eba664e64650b4b6d`: Tools14 pass; iPhone Accessibility3/3, Standard ink and navigation pass; iPad Accessibility, Standard ink and navigation pass. Eight native executions, zero failures. All original assertions/input/case deadlines retained.

Actual callback records match the tested phone rail and occur inside two captured drags: inherited cancellation0 → owned cancellation1 while the tool button tracks; native offset0→50. This verifies the intervention. The original inherited-policy handoff race is strongly supported; original callback invocation and all hosting-layout effects were not independently isolated. [Evidence and limitations](Verification/Diagnostics/rail-cancellation-39189664681.json).

Only the InkToolbar scroll holder changes. Its HStack/actions/picker/style are retained. Navigation policy, normal touch delivery, PencilKit and storage are unchanged. Effective compact width/content width match baseline. Natural Accessibility intrinsic height49.667 vs48 is documented; actual screenshots show usable targets and visible ink. No speculative height clamp is added.

The rejected delayed-touch-delivery experiment remains reverted. [Its report](Verification/Diagnostics/rail-delivery-39186654628.json). [Original failure capture](Verification/Diagnostics/rail-tracking-39187892547.json).

## Earlier integration result

Source `f2c376b7651c5d62bd92b49dc0cbdd3168a93910`, [run39277996098](https://github.com/x6one/hashiya-ios/actions/runs/39277996098): Stage A14 Tools/syntax/lint pass. Phone B4/5: both ink cases, document post-reopen Undo/Redo and navigation pass; the added margin fresh-stroke check fails321. Phone full C is not reached. iPad B5 and fresh-simulator C100/100 pass: 68 XCTest and32 XCUITest, zero failures/skips. Exported PDF/PPTX bytes pass. Maestro recording flow passes2m23; job reaches60min budget during a later flow, leaving final Maestro/capture gates incomplete. Actual two Accessibility ink screenshots reviewed. [Exact gate evidence](Verification/Diagnostics/full-pad-39277996098.json).

The added test input is invalid on the phone's fitted page: actual synthesized startx132 is outside paperx178.713–261.287. Old ink/count1 remain visible. [Exact screenshot/event evidence](Verification/Diagnostics/reopen-geometry-39277996098.json). This is a test-calibration error, not proven drawing loss. All original assertions/case deadlines remain.

Isolated correction `4c599d16dc8fc4b668f2a9154c8d1ef6548285bd`, [run39281549900](https://github.com/x6one/hashiya-ios/actions/runs/39281549900), tests the same existing phone margin case once with a centered vertical stroke inside the fitted paper. Production code and document gesture are unchanged. The native case passes200.905s with count2 after Undo/Redo and visible additional stroke. Overall diagnostic job fails only in post-test collection: persistent margins live under Documents, while the collector searched only tmp/ReviewEntry. The read-only collector now covers both locations; local regression tests demonstrate RED1/2 → GREEN2/2, including unchanged source bytes and outside-root symlink rejection. No native repeat was used to validate this postprocessing change.

## Retained final-gate design

The integration contains the bounded rail repair, public font resources for newly generated guide PDFs, Files fixture foreground cleanup, and equivalent single-query picker dismissal. A deliberate85% Back input replaces the previously cancelled65% test input; this is test calibration, not a claimed navigation production repair.

All32 original UI cases and224 original assertion lines remain. Two existing document/margin relaunch cases add a fresh stroke→Undo→Redo check. This does not assert persistence of prior-session undo history. Final verification removes the read-only CF/nav capture instrumentation by retaining the original PDFWorkspace source.

The pipeline runs Tools/lint, then the three original ink/navigation regressions in a separate matrix job. Only after both families pass, independent hosted runners execute full68 XCTest (all67 originals plus font regression)/32 XCUITest, exported bytes, three Maestro flows and real captures per family. Both document/margin post-reopen checks remain in full32. Separating phases prevents the observed aggregate60min budget exhaustion; case240/360 and job60 limits are unchanged. The extra compilation is an explicit cost of isolating state and giving the complete gate its existing full job budget. Native Office build/package follows successful family jobs. Every final gate must reference the same source SHA. These final-source results are pending.

Full native Office build is not runtime conversion proof: the current hosted path builds an unsigned iphoneos binary and has no configured provisioned physical-device destination for Word/Excel conversion. Record this as unverified; do not substitute simulator/host checks.

An unsigned IPA needs valid signing. No merge into main or Apple upload is authorized by this checkpoint.

## Preserved history

[Previous checkpoint](docs/history/STATUS-before-rail-cancellation-2026-10-19.md), [original status](docs/history/STATUS-before-rescue-2026-10-19.md), and [original verification](Verification/Diagnostics/0.6.0-13-before-rescue-2026-10-19.json) remain unchanged. Earlier partial diagnostics do not qualify the release.
