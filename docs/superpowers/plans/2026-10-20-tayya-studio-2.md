# Tayya Studio 2.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Deliver reviewable, real SwiftUI study prototypes before production redesign.
**Architecture:** A separate DesignStudio XcodeGen application exercises in-memory
sample state and PDFKit/PencilKit. The stable production target and data remain intact.
**Tech Stack:** SwiftUI, UIKit, PDFKit, PencilKit, XCTest/XCUITest, Python, macOS Actions.
**Spec:** `docs/superpowers/specs/2026-10-20-tayya-studio-2-design.md`

## Global Constraints

- iOS minimum 17; iPhone+iPad; production bundle `com.ahmadalawi.hashiya` unchanged.
- Phase A/B only; visual approval required before App/ production changes.
- Branch `design/tayya-studio-2` starts at verified dbdb264; no main/stable writes.
- No user data, paid services, Apple uploads, signing secrets, new product dependencies.
- Real simulator evidence; Arabic/English, RTL, dark mode, Dynamic Type, Reduce Motion.

## Review Focus

- Narrow phone / accessibility text: controls remain reachable, no PDF-covering dock.
- Page change during recording: session stays active and marker references new page.
- Marker activation at clip edges: page and clamped timestamp agree, no file loss claim.
- iPad rotation/split/focus: chrome can be restored, independent audio stays independent.
- Preview isolation: no production sources/container/config or user file mutation.

### Task 1: Audit and isolated state contracts (A/B)

**Files:** Create `DesignStudio/project.yml`, `DesignStudio/App/StudioSession.swift`,
`DesignStudio/Tests/StudioSessionTests.swift`, `.github/workflows/tayya-studio-preview.yml`.
**Interfaces:** `StudioSession` owns page, recording, elapsed, markers, seek/speed/title;
views consume it as ObservableObject. No PageAudio/storage calls.

- [x] Verify stable SHA/run; create separate worktree and remote branch at exact SHA.
- [ ] Write XCTest contracts before state implementation: recording page switch,
  writing/manual marks, seek clamps, clip rename preservation, speed bounds,
  interruption stop and independent margin state.
- [ ] Run isolated model RED probe on one macOS simulator. Expected assertion
  failures from unimplemented behavior, not compile or environment errors.
- [ ] Implement only sample-state behavior, run same tests GREEN with captures.

### Task 2: Design system and native proposal (B)

**Files:** Create `DesignStudio/App/StudioTheme.swift`, `StudioComponents.swift`,
`StudioLibrary.swift`, `StudioWorkspace.swift`, `StudioAudio.swift`,
`StudioDocument.swift`, `StudioApp.swift`; preview-only format/lint configuration.
**Interfaces:** Shared themed components consume StudioSession; document factory
returns PDFDocument; canvas uses PencilKit and stays in preview memory.

- [ ] Implement exact semantic colors/spacing/touch targets and localized copy.
- [ ] Library, phone study, iPad workspace, margin, audio and review screens.
- [ ] Wire prototype controls to working state/sheets; no decorative dead buttons.
- [ ] Unit-check actual symbol availability and contrast pairs on iOS.
- [ ] Format/lint changed preview files only; run state/unit/capture tests.

### Task 3: Evidence and approval package (B)

**Files:** Create `DesignStudio/UITests/StudioCaptureTests.swift`, `DesignStudio/README.md`,
`docs/design/tayya-studio-2-actions.md`; workflow exports screenshots/xcresult/manifest.
**Interfaces:** named screenshot attachments + summary JSON + source SHA manifest.

- [ ] Capture all five primary scenes light/dark on both families, tablet portrait
  and landscape, English and accessibility examples, focus and audio marker actions.
- [ ] Check actual geometry/reachability; review real PNGs before acceptance.
- [ ] Publish artifacts via Actions, provide links and exact SHA, stop for visual approval.

## Production rollout AFTER approval (C/D; do not execute now)

Each batch starts with the failing behavioral test, implements the smallest adapter,
passes focused regressions/captures, then commits. Keep the original 68/32/Maestro
requirements and re-qualify the final source on both families before any new IPA.

1. Library/system: `App/TayyaTheme.swift`, `LibraryScreen.swift`, `LibraryThumbnail.swift`,
   `LibraryDestinations.swift`. Reuse LibraryStore. Test search/sections/favorite/
   delete/restore/backup and old files. Introduce shared buttons/cards through adapters.
2. Phone editor: `App/PDFWorkspace.swift`, existing ink/navigation components. Preserve
   InkToolbarScrollView gesture ownership; test all tool targets, color/width, Undo/Redo,
   fit/page stability, selection/text, export bytes and reopening drawings.
3. Tablet/margin: `App/MarginPane.swift`, `MarginNotebook.swift`, `MarginPages.swift`,
   `PDFWorkspace.swift`, `LibraryDestinations.swift`. Add optional per-document split
   key with old global fallback; test rotation/drag/persistence/reading position,
   hidden thumbnails and restoring focus controls.
4. Smart audio: `App/PageAudio.swift`, `AudioLinks.swift`, `RecordingStrip.swift`,
   `PDFWorkspace.swift`, `DocumentPageRemoval.swift`, `LegacyPageRecordings.swift`.
   Add tested rename metadata API (retain clip filename), playback seek +/-10 bounded
   to duration, enableRate + allowed rates, page/ink/text/manual markers, optional
   compatible Codable metadata. Test mic grant/denial, permission cancellation,
   background/interruption/return, old linked+legacy M4A bytes, page delete/move and
   orphan visibility. Reuse existing audio peer/session ownership; no timer on workspace.
5. Extras: favorite pen presets, focus, thumbnails/search/last position, paper templates,
   document/page flashcards. Reuse `WritingPaper`, `Flashcards` and existing stores.
   Write tests for favorite round-trip, page/file filter correctness, each template,
   focus restoration, old data decode. Reopening persisted strokes and adding a NEW
   stroke Undo/Redo are distinct from restoring OLD undo history; never conflate them.
6. Full quality: original68+32+Maestro3 both families on final SHA, visual RTL/dark/type/
   ink review, real import/export bytes, original native Office iphoneos build. Document
   physical-device conversion as unverified unless actually exercised. Experimental
   unsigned IPA only if requested; valid signing required for installation.
