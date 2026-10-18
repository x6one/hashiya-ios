# Tayya rescue investigation plan

Use superpowers:executing-plans for inline execution. User authorizes routine development and CI; no merge or Apple publication.

Goal: determine causes before changing production behavior, then meet all release gates on one SHA.
Architecture: retain Paper Studio, PDFKit, PencilKit, file formats and version 0.6.0 (13). Isolate diagnostic changes from work/tayya-calm-workspace.
Spec: user rescue instructions, 2026-10-19 Qatar.

## Constraints
No assertion removal, deadline increase, sleeps, design changes, or repeated experiments without new evidence. Two failed attempts require new evidence. Preserve 67 unit, 32 UI, three Maestro cases per family and native Office packaging.

## Tasks
- [x] Verify c890352 HEAD and inspect both failed runs. Read source, workflows and baseline Tools (13 pass).
- [x] Verify PR phone artifact SHA256 and inspect actual failure video and native log.
- [ ] Navigation: record public edge recognizer enabled state/edge/direction under the existing boundary with the unchanged navigation test on both families. No production behavior change. Use result to choose one minimal correction, then run ink/history coverage before adopting.
- [ ] Palette: native service requested17:59:45.876, bootstrap18:00:03.111, ready18:00:05.800, after5s waiter. Determine system launch delay separately from presentation ownership; do not redesign presenter based on this failure.
- [ ] Redo: waiter fails but later actual count2 matches expected2. Need mutation timestamps vs AX sampling before claiming drawing loss or changing persistence.
- [ ] CI: prevent duplicate same-source jobs and separate targeted qualification from full release verification, retaining exact-SHA Office gate.
- [ ] Full release: 67/32/3 both families, exported bytes, actual UI review, full native Office build, IPA identity/resources/SHA256. No acceptance until complete.

## Review focus
Edge vs content gesture competition; sheet coverage/restoration; active stroke vs persisted data; reuse across reopening and suite history; diagnostic AX overhead.

## Ledger
2026-10-19: base c890352; no accepted repair. Linux has no Xcode. Diagnostic branch only measures public recognizer state, unchanged UI test, no release jobs. Candidate branch untouched.
