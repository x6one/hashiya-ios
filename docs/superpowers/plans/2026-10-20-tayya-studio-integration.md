# Tayya Studio 2.0 integration implementation plan

> **For agentic workers:** use superpowers:executing-plans for inline execution. Follow test-driven-development for behavior, systematic-debugging for failures and verification-before-completion for claims. User explicitly authorized this plan's execution without routine approval pauses.

**Goal:** Integrate the approved Studio presentation into the actual production app while preserving old data, native editing and all existing functions; qualify one SHA and package its real unsigned IPA.

**Architecture:** Existing LibraryStore/PDFWorkspace/MarginPages/PageAudio remain authoritative. Move approved tokens and chrome selectively, with reusable native components and narrowly scoped helpers for missing behavior. Never import StudioSession, StudioDraft or simulated audio.

**Tech stack:** SwiftUI/UIKit/PDFKit/PencilKit/AVFoundation, XcodeGen, XCTest/XCUITest/Maestro, existing Python checks and GitHub Actions macOS runners. No new dependencies planned.

**Spec:** ../specs/2026-10-20-tayya-studio-integration-design.md

## 1. Foundation and focused native gate

- [x] Inspect both current heads, local changes, actual baseline jobs and approved design evidence; establish isolated integration branch.
- [ ] Add a focused integration workflow using existing toolchain/simulator selection and retained xcresult evidence; exclude ordinary integration commits from expensive release jobs.
- [ ] Add failing native appearance contracts for approved semantic colors and a display-copy regression using existing Notes identifiers. Run that subset before changing production behavior.
- [ ] Update TayyaTheme semantic colors, add shared metrics/styles, change only displayed Notes copy and affected text tests; run the focused tests and relevant Python checks. Commit actual evidence.

## 2. Real library and language/accessibility

- [ ] Restyle LibraryScreen cards, continuation, filters/sidebar and empty states around actual Notebook data and existing actions. Keep identifiers and old data keys.
- [ ] Provide Arabic/English display strings and appropriate direction without translating persisted section names. Test long titles, accessibility text sizes, dark mode and real library operations; retain original tests.

## 3. Real PDF chrome and Notes

- [ ] Add the approved Pen/Text/Select/Notes/Pages dock and one active contextual rail. Route to existing native engine actions; keep study/files/page actions in clear reachable panels and adapt old test interactions without dropping assertions.
- [ ] Add Focus, compact recording chrome and adaptive iPad sidebar/split/expanded Notes. Preserve native host identity through layout changes, reading position, zoom, current tool and unfinished writes.
- [ ] Add directed UI checks for each real action, Focus/tool/layout continuity, RTL, accessibility sizes and both orientations. Run original ink/viewport/margin regressions only after the focused tests pass.

## 4. Real recording and data safety

- [ ] First add failing tests for corrupt marker preservation, same-recording page markers, display-name metadata, pause/rate/seek, manual markers and old-data reload.
- [ ] Extend real PageAudio and linked cards with rename, duration/date/page, pause/resume/rate/10-second seek, confirmation/delete/share and explicit recording/error state. Keep original M4A basenames and links; use no simulated waveforms as proof.
- [ ] Add optional stable source-page identity with safe legacy resolution and transactional page-deletion/undo handling; preserve unknown/corrupt bytes and original compatibility.
- [ ] Protect snapshots/page edits from active recording changes; verify permission denial/background/interruption and writing-marker routing. Preserve all existing audio suites.

## 5. Presets, thumbnails and study routes

- [ ] Persist three pen presets using native ink bindings and retain settings through reopen.
- [ ] Adapt the audited thumbnail algorithm to actual PDF pages: lazy, bounded cache, page identity and selective invalidation; verify different real page contents, edited/inserted/deleted pages and a large document.
- [ ] Connect existing flashcards, paper templates, Office originals, export and backup controls; test real output bytes and actual stored data.

## 6. Legacy compatibility and integrated validation

- [ ] Build a synthetic previous-version fixture with multipage PDF, PencilKit ink, text, independent Notes, decodable M4A/markers, cards, sections/favorites/trash and backup. Compare identities/content/bytes after opening, saving, relaunch and restore. Never use user account data.
- [ ] Run focused integration/compatibility suites on both devices; inspect xcresult and screenshots against the approved gallery. Diagnose failures before rerunning.
- [ ] Capture actual integrated library/editor/tools/Notes/split/audio/markers/thumbnails/Focus, light/dark, Arabic/English, large text and both orientations with source/test metadata. Produce a raw-image comparison HTML and ZIP.

## 7. Release gate and unsigned production IPA

- [ ] Complete code review and all required original/new XCTest, XCUITest, Maestro, exports, Office and accessibility checks on one final source SHA. Do not substitute design tests for production tests.
- [ ] Build that SHA through the existing native Office iphoneos pipeline; verify version/build/identifier, arm64, embedded resources/frameworks and Payload/*.app. Verify ZIP and record SHA256.
- [ ] Publish Actions artifacts and concise Arabic results with exact SHA/run links and physical-device limits. Leave the integration branch unmerged for review.

## Resume record

Baseline already verified: run 39342393075 at dbdb264. Do not repeat. Current task: step 1, first focused RED native test. Record new runs, hypotheses, modified files and exact results here after meaningful milestones; a running command must be identified before restarting it. No implementation changes existed at branch creation.
