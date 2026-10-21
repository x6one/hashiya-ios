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

### 2026-10-20 real frontend/data integration GREEN

Commit 6e8bcd6b2960124df928ee27d7ec6ffd2212e589, [run 39516649133](https://github.com/x6one/hashiya-ios/actions/runs/39516649133): both iPhone job 118950295343 and iPad job 118950295734 passed all 56 selected logic tests plus 4 real-production UI tests, zero failures/skips. This verifies the observed corrupt-store regressions, legacy fixture, original page/ink/audio/import/Office replacement suites and new real tools/Focus/Notes/English/accessibility rotation behavior. Full release gate has not been run.

Next independent RED is two production AVFoundation UI contracts: one clip continues across page changes and keeps both page timestamps; manual markers/rename/playback management. The current code has no initial/page-visit markers or manual-marker controls. Run only these new tests on iPhone to establish exact gaps before implementation; qualify both devices after the fix. This tests simulator audio, not a physical microphone.

### 2026-10-21 continuous recording RED and native audio candidate

Commit 0d3872fe121aae1603cf013ff2ac401b627487a9, [run 39518057594](https://github.com/x6one/hashiya-ios/actions/runs/39518057594), iPhone job118954881616: both new real AVFoundation UI tests ran and failed at intended contracts. Continuous recording retained one clip and remained recording on page2, but no initial marker existed (StudioAudioUITests:56). Recording details had no manual marker control (:70). Permission and actual recorder-time preconditions succeeded. This is simulator media evidence; no physical microphone claim.

Candidate keeps PageAudio/AVFoundation, old basenames, links.json and the retained document owner. Adds initial/page-visit/manual timestamps, optional pageID/notePageID/kind fields (old JSON still decodes), separate playback activity, pause/resume/0.5–2x/10-second seek, display-title metadata and real M4A share. Marker selection resolves the stable page, selects an existing associated Notes page without opening Notes, dismisses details and continues audio. Legacy PageAudio.play stop/replay semantics remain for original tests.

New additive files inside the existing backed-up audio folder: recordings.json (display metadata), page-identities.json (stable UUIDs, optional pending append intent). A pending append is written before PDF publication and resolves both pre/post-write crash states using the real PDF count; unknown mismatches fail closed. Existing page-deletion journal stages the identity map, metadata and archived deleted links/folders with PDF/ink/text/cards. Deleted legacy-page recordings remain browsable; linked recordings stay available for whole-document playback. Undo restores exact old index/links/metadata bytes. No directory/key/Bundle/version rename. Six new management tests cover actual AAC/M4A bytes, rename/reopen, damaged metadata fail-closed, pause/rate/seek/peer handoff, append recovery, stable deletion/archives/undo and actual backup restore.

Local Python19/19, modified whitespace/diff, workflow YAML and embedded Python parsing pass. Native audio candidate is not yet verified; next selection is audio, audio-controls and compatibility on both devices, not a full release rerun.

Intermediate native screenshots from 6e8 were inspected as original PNGs. They exposed an additional large-text visual issue despite basic reachability passing: inherited huge navigation SF glyphs and an instructional label overflowing its fixed contextual row. Preserve this finding for the next directed frontend geometry regression; these intermediate screenshots are not the final approval gallery.

### 2026-10-21 real audio UI GREEN / paused-seek investigation

Commit d5c98085aa2b636abd33e81831bc72cc82ab3871, [run 39519349232](https://github.com/x6one/hashiya-ios/actions/runs/39519349232): BOTH devices passed 35 of 36 selected logic/data tests and both real recording UI tests (37/38 total per device). Jobs iPhone118959097384, iPad118959097381. The sole failure is StudioAudioManagementTests:61: immediately after a paused forward seek on a real four-second AAC fixture, PlaybackActivity.time is0 instead of>3. All old audio/playback/deletion/page-removal suites, both legacy/corrupt-links contracts, old/new AAC/metadata/identity/backup cases and actual continuous-recording/manual-marker/rename/playback UI passed. No physical microphone claim.

One bounded hypothesis next: AVAudioPlayer may report a paused seek asynchronously. Add DEBUG before/target/actual/duration/paused values and await the actual player-derived activity publication for at most2seconds, retaining the same >3 and byte-preservation assertions. No production seek fix yet. A separate new zero-time-marker regression checks that selecting a start marker must restart playback instead of invoking the legacy whole-recording stop toggle. These are directed diagnostic contracts, not a full audio rerun.

The same native build adds two independent RED cases against existing production behavior: unreadable PencilKit ink must never be silently replaced/exported as blank; accessibility contextual prose must stay inside its44-point reserved area with readable instructions still reachable. Only an accessibility container identifier is added to production chrome for this RED; the adaptive frontend solution, native presets, thumbnail cache/grid/sidebar remain uncommitted and are excluded from this diagnostic source.

### 2026-10-21 confirmed remaining roots / bounded repairs

At 88ab25ec305fc33425b0bbd7980b91f2bd6c5623, [39521297069](https://github.com/x6one/hashiya-ios/actions/runs/39521297069), iPhone118965493439 and iPad118965493279 reproduced all four directed failures. Paused AAC seek traces show before0,target3.99,actual0,duration4,pausedtrue; actual player-derived publication stays0 after2seconds, disproving the asynchronous-read hypothesis. Seeking marker0 invokes the legacy play toggle and clears playing. Unreadable ink fixture29bytes becomes an empty PKDrawing42bytes and exports as a clean PDF. The accessibility container exposes51.33/51.5points of content inside a44-point row. These are synthetic-fixture/source defects, not lost user data.

Bounded candidate: prepare a fresh real decoder for a paused seek without starting sound, keeping URL/rate/pause and sampling the actual player time; add an explicit restart flag for marker selection while preserving legacy play-toggle behavior. Test a positive1.25-second marker against the native clock minus elapsed wall time so playback from0 cannot accidentally pass by waiting. Finalized M4A duration is read after stopping, including interruption/background cases. New real UI background/return/save/play test adds to the existing two cases.

Ink loads now expose errors and lock unreadable originals against writes, tool re-enabling and export; no filenames or old bytes are migrated. Adaptive contextual help keeps full accessible text in a readable panel while fixed SF glyph metrics fit the44-point rail. Notes selection retains its previous brush. Document exit clears owner-capturing callbacks. Native InkToolbarScrollView remains byte-identical to dbdb264.

This repair commit deliberately excludes the unverified preset/cache/sidebar/text-alignment candidate still in the working tree. Its focused native selection covers the modified audio/workspace/data paths on both devices; original ink/navigation UI regressions are queued for the separate preset/sidebar integration, before any release gate. Native success remains pending. Both string tables contain255 valid unique pairs; local diff/whitespace and workflow embedded syntax pass.

### 2026-10-21 bounded repair results and next isolated probes

At0ccdbbd9e3b415876462ef50e8379428df57aac5, [39523216382](https://github.com/x6one/hashiya-ios/actions/runs/39523216382), BOTH devices executed62 tests:60passed,2failed,0skipped. All54 selected logic cases except paused seek passed; all8 UI cases except the contextual-group measurement passed. Ink corruption protection is GREEN, native page/ink/Notes/backup regressions are GREEN, marker0 and actual1.25-second playback offset are GREEN, all three real audio UI cases (including background/save/return/play) are GREEN. A fresh prepared decoder did not change the paused3.99-second getter: still0. This is one failed production repair; do not accumulate more decoder patches.

The second failure exposes an incorrect test metric: a semantic accessibility group's frame is the union of drawn glyphs, not its44-point reserved layout. It is now19points after removing giant prose. The original native AX5 portrait PNG was inspected (phone artifact12312254230, SHA25641e81eabf9be599a3f6f8705bb57934b220c973986e98d810e768264cf8e6f13); the overflowing prose is gone and the contextual row is visually reserved. The revised test keeps44x44 on the actual help button, enforces that target below the PDF, checks contained text against that target and retains full accessible instructions/navigation limits. Log both group and button frames instead of assuming equal frames. No production UI change is bundled into this next diagnostic.

Next isolated phone build: directly probe raw AVAudioPlayer AAC offsets1.25/3.99 before/after play/pause with rate disabled/enabled. This distinguishes a getter/staged-position issue from an end-of-file issue before choosing another fix. It does not rerun the unchanged failing app test. Also add RED coverage for LibraryStore.importPDF/save bypassing the already-established persist/loadFailure guard (source audit found directJSON writes), and new UI contracts for native preset/accessible-preview components against the unchanged production UI. These UI contracts establish missing integration components, not a claim that the existing simple PDFKit thumbnails were fake.

The larger frontend candidate and real production capture fixture/helper remain local and excluded. Three local collector tests pass; no integrated final gallery/IPA exists.
