# Tayya Studio 2.0 integration implementation plan

> **For agentic workers:** use superpowers:executing-plans for inline execution. Follow test-driven-development for behavior, systematic-debugging for failures and verification-before-completion for claims. User explicitly authorized this plan's execution without routine approval pauses.

**Goal:** Integrate the approved Studio presentation into the actual production app while preserving old data, native editing and all existing functions; qualify one SHA and package its real unsigned IPA.

**Architecture:** Existing LibraryStore/PDFWorkspace/MarginPages/PageAudio remain authoritative. Move approved tokens and chrome selectively, with reusable native components and narrowly scoped helpers for missing behavior. Never import StudioSession, StudioDraft or simulated audio.

**Tech stack:** SwiftUI/UIKit/PDFKit/PencilKit/AVFoundation, XcodeGen, XCTest/XCUITest/Maestro, existing Python checks and GitHub Actions macOS runners. No new dependencies planned.

**Spec:** ../specs/2026-10-20-tayya-studio-integration-design.md

## 1. Foundation and focused native gate

- [x] Inspect both current heads, local changes, actual baseline jobs and approved design evidence; establish isolated integration branch.
- [x] Add a focused integration workflow using existing toolchain/simulator selection and retained xcresult evidence; exclude ordinary integration commits from expensive release jobs.
- [x] Add failing native appearance contracts for approved semantic colors and a display-copy regression using existing Notes identifiers. Run that subset before changing production behavior.
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

Baseline already verified: run 39342393075 at dbdb264. Do not repeat. Current task: step 1 GREEN verification plus isolated workspace/audio RED contracts and the complete old-data fixture. Record new runs, hypotheses, modified files and exact results here after meaningful milestones; a running command must be identified before restarting it. No implementation changes existed at branch creation.

### 2026-10-20 foundation RED evidence

Commit abfa532052f4a712f9d80dcd2612ca75e974c415, [run 39502023702](https://github.com/x6one/hashiya-ios/actions/runs/39502023702): both devices compiled the real production target and executed 2 tests. `testApprovedChromePaletteInBothAppearances` failed on 37 color-channel assertions (lines 22–24); `testChromeAppearanceDoesNotChangeStoredInkColor` passed. This proves the palette mismatch before its fix, not an app crash. Logs retained in Actions. The first iPhone run took longer during simulator/build startup; it completed its tests, not a hung command.

Next native selection combines foundation GREEN, new audio/workspace RED contracts, and legacy-compatibility verification in one build per device. No complete production gate has been repeated. App edits are approved palette/shared components, real library chrome/filter sizing and display-only Notes copy; existing paths, keys, IDs, data models and native engines are retained. Local Python remains 17/17.

### 2026-10-20 foundation GREEN / integration RED

At 9cbfdaa54ccc08fa6def6beaa5677e88b35fca83, [39503969075](https://github.com/x6one/hashiya-ios/actions/runs/39503969075), iPad job 118908122401 executed 15 tests: 12 passed, 3 failed. Both palette tests passed; all seven original PageRemovalTests passed; the complete literal previous-version folder/M4A/backup fixture passed; legacy audio identity passed; Notes display-name plus existing content passed. Expected remaining RED: missing approved core `selectTool`/Focus in two UI cases, and corrupt-links deletion overwriting 41 bytes with `[]` and deleting the M4A (StudioAudioIntegrationTests:17–21). This is verified data-loss behavior in a synthetic fixture, not user data.

iPhone job 118908121801 stopped before XCTest: SwiftFormat reported only consecutiveBlankLines at MarginNotebook.swift:390 (extra EOF blank line) and LaunchTests.swift:315. Those exact whitespace issues are corrected; do not repeat already-proven iPad RED contracts just for formatting.

Next isolated RED selection is English display copy plus four fail-closed storage contracts (text/cards/library/PDF), on iPhone only because these preconditions are platform-independent; both devices are required at GREEN/final qualification. In parallel, implement the now-proven real workspace/audio gaps. A new raw-PNG review generator has 2 meaningful integrity/context tests; local Python total 19/19. No gallery or IPA has been produced for integrated production yet.

### 2026-10-20 functional integration, first GREEN candidate

At 9de5072bb9e3183bcc38b551ca6c1da5bfe4526a, [39505826033](https://github.com/x6one/hashiya-ios/actions/runs/39505826033), formatting/lint passed. iPhone executed five new contracts: four data-safety tests proved unreadable library/cards/text/PDF could be overwritten; English core naming failed on Pen still reading قلم. These are observed RED results, not compiler failures.

Candidate changes: fail-closed load flags protect actual library/cards/text/PDF and throwing reads protect audio links; no schema/key/path renaming. DocumentScreen retains one NativePDF host and retained Notes/audio owners through Focus/split/expanded layouts. Approved five-tool dock and one active-target ink rail bind the existing engines; Notes uses its original canvas controller and mode-only native host boundary. The old four-group picker is replaced by a real document actions menu (workspaceActions); surviving action IDs remain. Original UI and Maestro changes only navigate to that real menu, reveal tools when automatic Focus applies, and measure the shared rail against both native panes rather than narrow Notes alone; original functional/pixel/undo/frame/deadline assertions remain. All 32 original UI method names are retained.

English/Arabic uses display resources and a persistent app-language preference; user titles, reserved section storage keys, Notes/audio files and ink colors stay unchanged. Native Files picker explicitly retains system locale/direction. Recording remains AVFoundation-based; the compact strip retains actual elapsed time and microphone level accessibility contracts. Data compatibility source fixture already passed before these changes and is selected again because persistence guards changed.

Next: focused workspace/audio/compatibility/library native verification on both devices. No full release gate or integrated IPA yet. Pending later work: real recording management/continuous-page markers, stable page identity, pen presets, bounded native thumbnails/sidebar, final production captures and final same-SHA release/Office/IPA gate.
