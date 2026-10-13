# Tayya Paper Studio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Implement the eight approved visual improvements while retaining data and the tested reading/handwriting behavior.

**Architecture:** Extend native semantic theme/brand components, then library presentation, then workspace/audio chrome. Existing storage and PDF/PencilKit coordination remain authoritative. Recording metering invalidates only a small local view.

**Tech Stack:** SwiftUI, UIKit, PDFKit, PencilKit, AVFoundation; XcodeGen and GitHub Actions.

**Spec:** docs/superpowers/specs/2026-10-12-paper-studio.md

## Global Constraints
- iOS 17 minimum; bundle com.ahmadalawi.hashiya; iPhone and iPad.
- No new dependencies, services, paid APIs, data schema changes, migrations, or deleted user files.
- Preserve all accessibility identifiers and existing flow labels.
- Preserve actual reading page/point, zoom and saved ink/text/audio when chrome changes.
- Version 0.6.0 build 13. No Apple upload, submission or PR merge.
- Use system Arabic fonts and Dynamic Type; controls minimum 44 points; respect Reduce Motion.

## Review Focus
- Narrow landscape and accessibility text: no clipped essential mode/action captions or overlapping controls.
- Reused notebook identity and replaced PDF: color remains stable and thumbnail cache refreshes correctly.
- First launch, repeated launch and Reduce Motion: entrance exits and never blocks library access indefinitely.
- Permission denied, interrupted recording and reopened notebook: status truthful, timers cleared and saved clips retained.
- Pen toggles, split resize and audio start/stop: no document page jumps or unexpected margin opening/resizing.

---

### Task 1: Theme and fold identity
**Files:** Modify App/TayyaTheme.swift, App/AppEntrance.swift, App/WelcomeScreen.swift, App/LibraryScreen.swift (initial welcome gating only). Create App/NotebookCoverStyle.swift if needed for deterministic color identity.
**Interfaces:** Preserve every TayyaTheme existing token and TayyaFold. Add static semantic tokens copper/detail/text/mutedSurface if useful, and reusable FoldedPageCorner View. Produce NotebookCoverStyle.color(for: UUID) -> Color; use stable UUID bytes, not randomized hashValue. Other tasks consume these views/tokens. Add defaulted LibraryScreen.allowsInitialWelcome: Bool = true; keep its URL intake mounted while AppEntrance gates only welcome presentation.
- [ ] Read the approved spec and current files. Refine warm light/dark palette and system typography without tinting PDF content.
- [ ] Add native decorative folded-page corner and stable green/sage/sand/copper-muted cover colors; decorations accessibilityHidden.
- [ ] Keep LibraryScreen mounted throughout entrance, using the new input to defer only initial welcome until entrance finishes. Make AppEntrance run the short paper-to-fold motion on first launch only using a new UI-only AppStorage flag, with 'By Ahmad Al-awi' credit; honor Reduce Motion and cancellation. Maintain openingAnimation identifier.
- [ ] Restyle WelcomeScreen with fold identity, clear Arabic hierarchy and >=44pt actions while retaining all callbacks and identifiers.
- [ ] Self-review first/repeated launch, text scaling and dark contrast. Run git diff --check. Native checks are deferred to Task 4 because this Linux environment has no Xcode; do not claim they ran.
- [ ] Commit only owned files and write task report with API additions and remaining verification needs.

### Task 2: Library covers and hierarchy
**Files:** Modify App/LibraryScreen.swift and App/LibraryThumbnail.swift. Existing LibraryDestinations.swift only if presentation styling needs consistency.
**Interfaces:** Consume FoldedPageCorner and NotebookCoverStyle.color(for: UUID) from Task 1. Preserve LibraryThumbnail(url:) and all library navigation/action identifiers.
- [ ] Read current library structure and approved spec; improve visible header, card hierarchy and sidebar/tab alignment using theme tokens and system fonts.
- [ ] Give each notebook a stable tinted cover frame/spine with small fold detail; show actual PDF first-page image inside it. Title and metadata align across grid, including long Arabic names and accessibility Dynamic Type (one column).
- [ ] Keep cached thumbnail computation off the main thread. Reset stale image when URL changes and prevent a delayed result for one URL being displayed for another.
- [ ] Add restrained selection/navigation motion only to chrome and honor Reduce Motion; preserve search/import/section/trash actions.
- [ ] Self-review 2-column phone and adaptive pad, long titles, actual PDF thumbnail and dark palette. Run git diff --check and record native verification pending.
- [ ] Commit owned files and write task report.

### Task 3: Writing workspace and independent audio strip
**Files:** Modify App/WorkspaceTools.swift, App/PDFWorkspace.swift, App/MarginPane.swift, App/PageAudio.swift, App/AudioLinks.swift. Create App/RecordingStrip.swift for local progress views. Modify Tests/WorkspaceAudioTests.swift or Tests/AudioPlaybackTests.swift for new recording/playback invariants.
**Interfaces:** Preserve WorkspaceAction initializer and every accessibility identifier/value, PageAudio start/stop/play/delete/scene lifecycle and clip/link formats. Add small recording activity observable owned by PageAudio for elapsed time and real meter samples, observed only in its meter subview. RecordingStrip receives PageAudio and the existing start/stop action; no coupling to margin state.
- [ ] Refine grouped tool chrome, selected shape, consistent icon weights and Dynamic Type labels. Keep essential actions >=44pt, adaptive phone/pad structure and native group Picker identifiers.
- [ ] Improve page counter baseline/alignment, margin mode label visibility and split grip/separator. Keep divider hit area and all drag/adjustable behaviors; do not modify PDF viewport capture/restore or PencilKit coordinator.
- [ ] Add recording duration and real bounded metering in a small strip near study tools, occupying stable height before/during recording. Never open/resize margins for recording. Timer/meters stop on permission denial, stop, scene interruption and deinit; isolate progress invalidation from NotebookScreen/PDF representable.
- [ ] Coordinate legacy/linked playback through the existing sheet lifecycle so simultaneous playback cannot occur; preserve old files and page association.
- [ ] Add meaningful native tests for stopped/denied recording activity reset and real playback handoff where applicable; include pending-permission cancellation invariants. Do not add tests that merely mirror cosmetic constants. Native red/green awaits CI; report this explicitly.
- [ ] Self-review APIs, permissions, recordings and state identity; run git diff --check, commit owned files and write report.

### Task 4: Release validation and visual captures
**Files:** Modify project.yml, UITests/LaunchTests.swift, .github/workflows/ios-check.yml, README.md, STATUS.md. Create Verification/0.6.0-13.json for actual known evidence only.
**Interfaces:** Consume finished Task 1-3 UI. Existing CI imports/handwriting/audio/library/card lifecycles remain gates.
- [ ] Bump version to 0.6.0 and build to 13; retain bundle/deployment/family values.
- [ ] Add one focused UI journey capturing polished library, document tools, split handwriting and recording presentation. Capture first-launch/welcome branding, light/dark and wide/compact variants using actual UI. Preserve existing 18 UI cases and all Maestro flows; no weakened assertions. Add a cold first-launch external-document regression case using XCUIApplication.open(_:) and an owned PDF fixture when supported, verifying actual imported content.
- [ ] Increase test job timeout from 40 to 60 minutes: the prior real PR attempt finished all three Maestro flows then was cancelled during shutdown at 40 minutes. Keep individual test timeout 240 seconds and all checks enabled.
- [ ] Document current candidate state without claiming tests or build before they run. Run git diff --check and Python release-tool tests where available.
- [ ] Commit and write report; controller publishes combined source to authorized branch, runs exact-source CI and inspects screenshots, fixes material findings through implementer review, then builds full native Office IPA with archive-only signing, persists verified outputs and updates actual evidence.
