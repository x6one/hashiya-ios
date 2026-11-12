# Tayya precision ink update implementation plan

> **For agentic workers:** Use superpowers:executing-plans. The owner approved implementation and conditional App Store publication; no routine reapproval.

**Goal:** Ship0.6.2 with straight line/highlighter, selected-stroke straightening/recolor/width and native ruler on real PDF and Notes, retaining all data and undo.
**Architecture:** Shared canvas-attached controller and pure PKStroke transformations. Existing independent canvas UndoManagers, coordinator persistence and stored .drawing/Notes data remain authoritative. Transient mode/selection/ruler state stays outside old InkBrush/preset formats.
**Tech Stack:** SwiftUI/UIKit/PDFKit/PencilKit, iOS17+, XcodeGen, XCTest/XCUITest, macOS Actions.
**Spec:** docs/superpowers/specs/precision-ink-design.md

## Global constraints
- Source base d45457bdd216265b11d58ba844fcda22fb6297d9; stable integration and main app code unchanged.
- Existing published version0.6.1; target0.6.2, select unused build through official Apple metadata before signing.
- No OCR/text-baseline guessing, arrows/laser/endpoint magnets in this release. Existing .drawing names, page IDs, audio anchors, presets and accessibility IDs retained.
- Commit precision edits once, only after stroke completion. One Undo/Redo per edit; preserve earlier native history.
- No Xcode on Linux, no paid services, no secret values in logs/source. Never waive a failing release gate.

## Review focus
- Transformed, masked, sparse, overlapping and stale-selected strokes; do not mutate unrelated strokes/order.
- Active gestures, page switch, late native callbacks and split relayout; no ink committed to wrong page or SwiftUI reload.
- Notes editing must not add audio writing markers for recolor/width/straighten or their history.
- Native ruler vs custom single-touch line gestures; keep two-finger pan/pinch and freehand responsive.
- Production export/reopen and original history isolation, not just stroke counts.

### Task1 — geometry RED/GREEN
- [ ] Add InkStrokeEditing API with no-op contracts and PrecisionInkTests for selected-middle straightening, preservation, midpoint/transform/overlap hits, color/type/alpha, width and constant-width line.
- [ ] Commit tests with focused macOS selector [integration:precision-ink-red]. Confirm actual assertion failures, not compile/infrastructure errors.
- [ ] Implement minimal geometry and run same suite GREEN on both families.

### Task2 — transactions and canvas lifecycle
- [ ] Add controller transaction/history tests first, including both actual canvas managers and no-op/no extra native actions.
- [ ] Implement shared controller, custom selection in explicit selection mode, exclusive line preview/commit, geometry conversion, ruler configuration deferred while stroking.
- [ ] Wire production callbacks and commit reasons; preserve Notes synchronous save/deferred publication and audio markers.
- [ ] Run focused geometry+native owner/persistence/audio and old compatibility regressions.

### Task3 — production controls and visual proof
- [ ] Add UI regression expectations for actual line/selection/straighten/ruler on PDF and Notes; then wire compact contextual controls, AR/EN strings and selected color/width.
- [ ] Capture real phone/pad light/dark, portrait/landscape and large type; review output and actual exported rendered marks.

### Task4 — release qualification and publication
- [ ] Fresh reviewer of complete code; fix important findings with regression tests.
- [ ] Prepare0.6.2 metadata and bilingual What's New; fresh native store captures if needed. Add source-bound publishing/archive retention fixes before freeze.
- [ ] Full production gate on one SHA: all original+new native tests, Maestro3, actual exports, gallery, Office arm64 engine and iphoneos packaging.
- [ ] Signed archive+IPA on same source, signature/contents/hash, official ASC upload, processed build linkage, AR+EN metadata and official App Review submission with automatic release.
- [ ] If credentials/API permissions block, preserve code/evidence/artifacts and state exact proven barrier; never claim Apple status without receipt.
