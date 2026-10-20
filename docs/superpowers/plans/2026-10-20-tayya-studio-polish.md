# Tayya Studio 2.0 polish implementation plan

> **For agentic workers:** Use superpowers:executing-plans inline, task by task. User explicitly authorized implementation of this polish round and review of actual simulator images before integration.

**Goal:** Refine the existing isolated SwiftUI prototype and deliver a single old/new native screenshot artifact.
**Architecture:** Keep production storage and targets untouched. Retain Root-owned PDFKit/PencilKit instances; share PDF thumbnail rendering/cache between sidebar and picker. Preview preferences/drafts use the preview sandbox only; audio remains an explicitly identified interactive simulation.
**Tech Stack:** SwiftUI/UIKit/PDFKit/PencilKit, iOS 17+, existing XcodeGen/XCTest/XCUITest workflows; no dependencies.
**Spec:** Latest user's final-polish brief; existing `docs/superpowers/specs/2026-10-20-tayya-studio-2-design.md` continues to define approved identity and prototype boundary.

## Global Constraints
- Design branch only; production bundle com.ahmadalawi.hashiya unchanged; version 0.6.0 build 13 unchanged.
- Rename visible Margin copy to Notes / الملاحظات; preserve internal identifiers, all storage paths and accessibility IDs.
- Existing palette; minimum 44×44pt interactive targets; system Dynamic Type, RTL and Reduce Motion.
- No stable merge, Apple upload, signing, paid services or new packages.
- Native simulator images only; never present simulation as real microphone/file-conversion proof.

## Review Focus
- Very narrow landscape height + accessibility text: keep Notes and tools reachable without overlapping PDF.
- Hidden/reinserted PDF must retain zoom, page and destination; native page changes update navigation.
- Rapid thumbnail requests/invalidation: stale renders must not replace newer revisions.
- Interrupted draft/preset writes: atomic writes, visible save errors and no production paths.
- Marker activation while Notes already open: preserve layout preference rather than opening a closed Notes panel.

## Task 1 — Pin visual defects before implementation
**Files:** `DesignStudio/UITests/StudioCaptureTests.swift`, `.github/workflows/tayya-studio-preview.yml`.
- [x] Add focused UI tests for Notes copy, contextual tools/compact audio, expanded accessibility Notes, real thumbnails and large library filters. Preserve previous assertions.
- [x] Run ONLY new UI tests on both macOS simulator families using `[studio:polish-red]`; extract actual assertions. Do not repeat old successful suite.

## Task 2 — Adapt workspace and shared components
**Files:** `StudioWorkspace.swift`, `StudioTheme.swift`, `StudioComponents.swift`, `StudioRoot.swift`, `StudioLibrary.swift`, `StudioAudio.swift`.
- [x] Rename display strings only; tokens for spacing, targets, radii and minimum Notes width.
- [x] Clamp split to readable Notes width; expand Notes at accessibility sizes, with explicit document/Notes switch and return to split at ordinary sizes. Retain PDF instance.
- [x] One primary tool row with horizontally scrollable whole labels at large sizes; only selected contextual rail. Remove add-text overlay in favor of contextual controls.
- [x] Compact inactive recording row; readable active marker state, recording metadata and full hit rows. Keep page/time linking and continuous recording.
- [x] Large library chips have intrinsic widths and selected traits; consistent spacing.

## Task 3 — Native thumbnails and existing small features
**Files:** new `StudioThumbnails.swift`, new `StudioDraft.swift`, `StudioDocument.swift`, `StudioSheets.swift`, `StudioSession.swift`, unit/UI tests.
- [ ] Tests first for thumbnail pixels/page differences/revision invalidation; real PDFView viewport retention; atomic preview draft reopen and three editable pen presets; last visited page. Run focused tests RED before implementation.
- [x] PDFKit rendering on a serial background worker using independent immutable document data, bounded NSCache and revision-checked publication; lazy reusable cell in sidebar/picker, number and selected outline.
- [x] Reuse focus; preview-only atomic autosave with honest status; three saved pen settings and quick access; text size/color/alignment editing, direct page jump and previous visited page.
- [x] Respect Reduce Motion for brief selection transitions.

## Task 4 — Verify and deliver
**Files:** UI captures, gallery builder/workflow, evidence/review docs.
- [x] Targeted GREEN for changed contracts, diagnose logs before rerun. Compact-height follow-up is native3/3 in39397149322.
- [x] One full DESIGN suite on both families at same final source SHA, include portrait/landscape, light/dark/ar/en/large type, pen/text/select/focus/audio/Notes/thumbnails.
- [x] One fresh-context final review; fix important findings with focused regression coverage.
- [x] Reuse verified 65 prior PNGs; package old/new side-by-side HTML and original new PNGs in one artifact with SHA manifests. Inspect actual representative PNGs, report exact tests/source SHA and prototype limits; await visual approval before integration.

Verification ledger: `docs/design/tayya-studio-2-polish-review.md`. UI RED and review regressions have native evidence; not every helper unit had an executed RED before implementation. The first Task 3 checkbox therefore remains open as a recorded process limitation, not a missing implementation.

## Visual-gate follow-up (fee2194)

Both38-case gates passed, but actual AX5 landscape phone capture left PDF almost
no height. Add a failing geometry/state regression first, then reuse reversible
focus by default only for phone accessibility sizes at compact height. Keep a
44pt Show tools control; preserve page8 and explicit manual focus across rotation.
Tablet regular-height behavior stays manual. Focused GREEN includes the existing
real PDF viewport unit and extreme-type captures. After it passes, final full
39-case coverage adds English/dark focus and capture orientation readiness (native
app screenshot after window aspect matches device); retain unmodified old PNGs.


## Capture-method follow-up (6d513cf)

Full17unit+22UI passed each family,0 failures/skips. Actual landscape PNG review
found app.screenshot crops/EXIF inconsistent, so those images are not delivered.
Read-only original-image landscape contract observed RED; original XCUIScreen
capture satisfies it. Restore full-screen screenshot after window readiness and
add orientation-aware pixel/window aspect assertion. Run ONLY12 UI capture cases
both families with exact App/Tests/project hashes pinned to the full6d gate.
No unit/unrelated UI replay and no application modification. Keep full39 evidence
and corrected-capture SHA separate and explicit in the final manifest.

Capture follow-up complete: e15 run39401061917 passed12/12 each,0 failures/skips; all95 original PNG SHA/orientation checks pass, representative pixels reviewed. Full39 behavior remains6d with identical app tree. Gallery160 originals prepared for Linux-only artifact publishing; user visual approval remains required.
