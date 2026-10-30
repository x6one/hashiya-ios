# Tayya0.6.0 public release implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans task-by-task.

**Goal:** Qualify one fixed production source, sign/upload it, prepare truthful Store metadata and existing artwork, submit App Review with automatic release after approval, and verify actual Apple state.
**Architecture:** Preserve native production engines/storage. Use existing opt-in release push marker to start the unchanged comprehensive gate, then consume its exact Office artifact with the existing Store/distribution controller. Manual QA workflow stays independent and unqualified; registering its sole CI file on main does not merge application code.
**Tech Stack:** Existing macOS/Xcode/GitHub workflows, original Python native tools, Node Apple/Store tools and normal CI secrets.
**Spec:** Owner's latest pasted Final Autonomous App Store Release (October28,2026) explicitly excludes owner manual testing as a release prerequisite and authorizes the existing app6818288428 upload, App Review and automatic public release; no repeat permission required.

## Global Constraints

- App6818288428; bundlecom.ahmadalawi.hashiya; marketing0.6.0; Build13 or a new valid higher build if used; min iOS17; iPhone+iPad.
- Production branchintegration/tayya-app-store. Only approved workflow registration onmain; no application/stable merge or user-data modification.
- No secrets disclosed, new paid services, GPU tracing, repeat diagnostic loops, disabled tests or altered success thresholds.
- Explicit publication authorization supersedes prior no-review/no-publication restrictions. It does not make a failed gate successful or prove physical-device behavior.
- Automated verification is the release gate; physical microphone quality/interruptions/Office device-runtime limits are disclosed, never made an owner manual-test prerequisite.
- Existing12 genuine Store compositions must remain accurately attributed; review current capture compatibility rather than relabeling source commits.

## Review Focus

- Exact native/engine/controller/build/artwork provenance and same-source qualification.
- Data loss vs saved stroke vs live presentation remain separate; unresolved simulator failure is retained and any new failure analyzed before retry.
- Actual valid distribution identity/profile/arm64/iphoneos/resource checks, not secret-presence or simulator proof.
- Apple processing/export compliance/privacy/contact/age metadata must be truthful; no automatic speculative declarations.
- Upload acceptance, processed build, review submission and actual public distribution are separate states, each verified through Apple.

### Task1: Register and qualify

- [x] Verify current integrationcd22 and mainb38; register the previously reviewed single manual-workflow file onmain only, commit60d58786315a84ee72ad8c0662ae98bde83929c6. GitHub registered active workflow398786579.
- [ ] Freeze the marked release-request commit; unchanged comprehensive workflow executes original4 cold/device, all152+ native/device,3Maestro/device, actual exported bytes, gallery and native Office/device package.
- [ ] Read actual native evidence if any gate fails. No unchanged retry or old GPU experiment.

### Task2: Native distribution and Store preparation

- [ ] After successful same-source gates, validate current Apple build availability and signing material; preserve original engine/link/build/distribution mechanisms.
- [ ] Produce verified signedIPA/XCArchive/unsignedIPA and hashes; upload, then independently confirm exact version/build processing.
- [ ] Reuse12 genuine Store images after actual compatibility review; verify ar/en listing, current age/privacy/encryption/contact metadata without changing live0.4.2 prematurely.

### Task3: Submit and verify public-release state

- [ ] Extend only the isolated Store orchestration as needed, with meaningful regression tests for wrong-build, failed qualification, missing metadata and duplicate submission rejection.
- [ ] Attach the exact processed build; configure AFTER_APPROVAL release; use current official App Review API to submit and read actual state.
- [ ] Address actionable Apple rejection/information requests; never invent acceptance. If Apple is still reviewing, preserve exact pending status and resumption mechanism; only claim public0.6.0 after actual distribution state and Store link verification.

### Task4: Finish remaining native release blockers from actual production paths

**Files:** `Tests/StudioUndoIsolationTests.swift`, existing `.github/workflows/tayya-integration.yml`; only if reproduced, `App/InkSelection.swift` and `App/MarginNotebook.swift`. Existing production surfaces/storage and original UI tests stay intact.

- [x] Resume6fc6ec8 clean remote/local; QA14 actuallyREADY_FOR_BETA_TESTING; no new signing or healthy-test rerun yet. New official candidate must use an unused15+ build.
- [x] Compare actual0.4.2 source referenceb38b985 (version confirmed; exact published binary source attestation not available) with current `LassoCanvas`, `MarginCanvas`, `NativePDF` and Notes reload. Both versions inherit UIKit UndoManager; Notes reload clears all actions. Current standalone mounted route contracts pass, and Notes was absent during the old document-only Undo failure, so shared-owner reset is NOT yet that failure's proven cause.
- [x] Add `testSwitchingNotesPagePreservesDocumentUndoInActualSplit`: mount actual `NativePDF` and `MarginPane` in one real UIHosting/window; register one known document drawing operation, then use real `MarginPages.add(linkedTo:)` and await its actual `MarginNotebook.Coordinator.pageID`. Through production workspace callback, Undo must clear only the document operation and preserve Notes. No manual peer reset, fabricated hierarchy, new diagnostics or timeouts.
- [x] Run only this new regression/device on macOS (40740875695: genuine canUndo/drawing-count failure on both devices). Expected: either genuine failure after actual Notes configure (then minimal per-canvas manager ownership fix) or PASS (hypothesis disproved; no production patch). Preserve original2 route tests and original UI assertions. This validates ownership, not native gesture registration or the old pre-Notes failure.
- [x] If RED, implement only the proved ownership fix and run new regression+existing actual route contracts+unchanged Standard/Accessibility real-stroke UI/device. If remaining pixel/Undo fails, analyze retained evidence once, no identical retry or GPU tracing.
- [ ] After all targeted required contracts pass, query actual Apple maximum build, freeze source15+ and run comprehensive gate once (all original/new methods, Maestro3, actual exports, gallery, compatibility, Release/nativeOffice). Keep publicdisabled on any mandatory failure.
- [ ] Use existing Store controller's verified12-image/evidence-bound metadata path; signed IPA/archive, actual processing, exact build attachment, review/AFTER_APPROVAL and Apple state readback. Report official state, not TestFlight readiness as publication.

- [x] Additional concrete0.4.2→current lifecycle regression: original Notes saved each drawing change; current buffers until tool-end but its dismantle only logs inDEBUG and has noRelease flush (NativePDF already flushes on dismantle). Add `MarginInkLifecycleTests/testSwitchingNotesToTextFlushesUnfinishedInkToItsOriginalFile` using actualMarginPane+MarginPages+PKCanvas delegate callback sequence, then actual handwriting→text teardown and reopen on-diskPKDrawing. Run only thisnewcase/device after the active split-owner baseline ends. IfREDatmissingdiskink, add final synchronous pending-ink flush and detach delegate in actualMarginNotebook.dismantle, preserving end-of-stroke saving otherwise; rerun thiscase+relevantcommit/safety and original UI regressions. No new diagnostics or changedUIthresholds. This is independent of pre-Notes document Undo and delayed live presentation.

October29 verified result:40740875695 reproduced actual-split document Undo loss on both devices; fc01abf private per-canvas UndoManager preserves independent histories. The unchanged native regression passes. A separate interrupted Notes lifecycle defect was reproduced on disk, then repaired with synchronous atomic persistence and deferred SwiftUI publication; reviewed archive/tool-end gaps were reproduced on both devices in40853227147 before their production fixes. Final targeted40855920579 on10b0038 passed19/19 per device, no failures/skips. Original Standard real-stroke/Undo/Redo UI passed both in40846679049; previous failed Pad Accessibility UI passed40853227147. All original UI assertions and committed real-split test remain unchanged. This does not retrospectively assign a cause to unrelated old document-only failures.

Freeze candidate15 from10b0038 (Apple read-only40846693542 observed13/14 used,15 available; duplicate guard remains required). This request changes no App code. Require160 native cases per device, original4 cold regressions/device, Maestro3/device, actual byte exports, gallery and complete native Office/iphoneos package on this exact source. Current Store captures are required to bind the existing approved12 compositions to the repaired Release source; use the established renderer without redesign. Keep internal QA14 immutable and public publication disabled until exact-source gates pass.

### Task5: Bound native Notes commit/presentation side effects before final publication

Owner resumed October29 with signing/upload as the goal. Existing actual-split Undo and interrupted Notes storage fixes remain verified; do not reopen them. Source061 cold gate proved only the iPad Accessibility split live-pixel failure, while valid2stroke ink remained on disk and independently rasterized3905red pixels.

- [x] New mounted production test `testNotesStrokeCommitsBeforePublishingIntoSwiftUI` exercises End-last and End-before-final-Change ordering. Require disk/getter ink synchronously, no Observable/parent presentation effects inside delegate handoff, and exactly one eventual saved callback. Baseline only thisnew1unit/device on d250c5; no unchanged pixel retry.
- [x] Only after genuine inline-publication RED, route normal Notes saved closure through the existing atomic/deferred presentation path already used on representable transitions. Preserve synchronous durability, page UUID and every native Undo/data/UI assertion. This is a causal hypothesis for live visibility, not a claimed resolution.
- [x] Verify all20relatednativeunit/device plus only the previously failed original Pad Accessibility UI (21Pad); do not repeat healthy Phone/Standard UI before the final cold gate. If pixel still fails, reject this hypothesis and investigate new code evidence before any further patch; no stacked fixes or newGPU tooling.
- [ ] After targeted green, select actual unused build15+; freeze all161cases/device+Maestro3+realexports+gallery+Office/iphoneos and current Store captures on one source. Reuse approved compositions. After exact-source success, signed archive/IPA, Apple acceptance/processing, AppReview submission and AFTER_APPROVAL remain explicitly authorized. No owner manual-test prerequisite; internal14 stays untouched.

Task5 genuine baseline40924490531 on d250c5d0e15a25085316d36f9ec7d40489a462bc:1newtest failed both only at61/62 for inline observable publication and parent effect (counts1then2); all synchronous disk/getter/count and eventual delivery assertions passed. Pad2.037s,Phone5.125s. No pixel baseline repetition. Minimal production change only MarginPane.swift unifies normal and transition saved callbacks through existing safe synchronous store.saveInkDuringViewUpdate + deferred parent callback. The causal live-render hypothesis still needs unchanged PadAX originalUI; do not claim fixed from deterministic boundary test alone. Next [integration:ink-atomic-publication] is20unitPhone/21Pad (20unit+failedAX), preservingalloriginal UI/5s/>40pixel assertions.

Task5 verified40926031496 sourceb4d4c1540b46fec3ce4963e6bb3b997dc79f9461/App2eb2a2ac53b5678768ed9d9cf6926295163d0acd:20/20Phone,21/21Pad(all20unit+unchangedoriginalAXrealstrokeUI232.719s),0fail0skip. No screenshot/time/Undo condition changed. Fresh whole-production reviewer native_callback_release_review: noCritical/Important, old archivedaudio-source/ordinalMinor remains unchanged/deferred; native pixel causality is bounded by actual targeted and forthcoming cold/full results. Currentread-onlyApple40926419478(509Bartifact12919404033,SHA6d8b3a500c2b55e744c65d2164ee8f3be0e17aff30db38a2acf6aeacc05cb9a7) observed13/14VALID and15free; neverreupload14.

Freeze this source with161native/device107unit54UI+4cold/device+3Maestro/device+realexports/gallery/Officeiphoneos. Capture existingapproved12compositions on this exact source; new native metadata audit verifies installed BundleID/version/build after capture, no sourceimage manipulation. No further integration pushes while gates/package active. After allmandatorygatesgreen, existing isolated Store controller may sign/upload new15, verify actualAppleprocessing, submitAppReview andAFTER_APPROVAL under owner's existing authorization. Nomanualownerstep/GPUtools/paidservices/mainmerge.

### Task6: Preserve the real Next-page condition while fixing its XCTest observer

Exact-source40928381699:Phone161/161 andMaestro3/3 plus actual exported bytes passed. Pad107unit/53UI passed; only `StudioProductionCaptureTests/testArabicLightProductionStudyScreens` failed at94 in the client-side page-value predicate. Every original drawing/Undo case passed, including both Standard/Accessibility journeys. No unchanged retry or production change follows from this observer failure.

Original evidence:diagnostics-iPad12928804667 SHAa2e99ef4ec2b6f9266bb96007fdb57ee3c4c013e0cb3dfca7291d554f256fdde. Two connector timeouts prevented local484MB retrieval. Linux-only40949495050 recovered9unaltered files,0builds/0tests;3.7MBartifact12929744183 SHA402fe6f334b439668115d75e4413cc50428d2bcdd89f1d49715852c3e4bc4b11. Original AfterPNG and model showpage2/5; MP4lastframe41.64s already shows page2 before the first waiter AXread at42.53s. Event attachment proves center touch814.5,108.5 inside the44ptNext target. The false failure is in nested synchronous remote AX polling, not a missed touch or lost drawing.

- [ ] Replace only Next/Previous readiness polling with a native query matching the same pageNumber value and unchanged5s timeout. Preserve center touch,44ptbounds,increment1 andreturn-page assertions; additionally require the production document page model independently of its editable field.
- [ ] Add a negative control which rejects unchanged page1 when waiting for2, then exercises the actual Next/Previous controls. Run only this control and the original failed complete light journey on both devices via `[integration:page-transition]`.
- [ ] After targeted green, freeze a162case/device candidate (107unit55UI), run the mandatory comprehensive gate once on that source. ProductionApp/Office/version/build remain identical to photographed7980, so reuse its12approved actual Store images. Preserve internal14. Only after allmandatorygates pass may the authorized signed15 upload/AppReview/AFTER_APPROVAL proceed.

Observer review native_page_observer_review: noCritical/Important, native query API/5s/touch/increment/restore/negativecontrol retained. Minor wording corrected: pdfCanvasAX page reports production workspace.page, not independent PDFKit visible destination; original video provides visible-page evidence. Fresh Apple read-only41037591386 confirmed13/14VALID and15unused; receipt508Bartifact12968582966 SHA284c2ac7b37a69bb1a9aacbf240e7fe13956322044816a62e20d0d317ae573bb. No reservation/upload.


October30 targeted41036303306: Next/Previous state query and new unchanged-page negative control pass both devices. The original full light journey gets past navigation, then fails at227 on favorite-pen commit both; this is a separate new failure, not evidence against the passed Next observer. Pad artifact12968816656(133981876B,SHAfa755980bb462d493710e832abd609c346008c6f9b521ca5dbb07b16122e5ede) was downloaded once and verified locally. Its query failure namespdfCanvas, and video105s still shows the native menu after selection. No execution/observer-only conclusion follows from menu pixels alone.

Review established a concrete test precondition defect: background trace/page/strokes were read AFTER opening Favorites (nilpage/strokes accepted), and commit was observed BEFORE menu dismissal, contrary to existing ProductionUIHelpers contract. No production issue is proved. Capture required nonnil state before opening Favorites; reuse existing tapCompletedNativeMenuItem (enabled/visible row, one center touch, native absence5s); only then retain the unchanged apply-counter/pen/width3 predicate5s and page/strokes retention. No extra touch, auto-dismiss, sleep, weakened assertion or new diagnostic instrumentation. Target only original full light journey + existing unselected-open-menu negative control on both devices via `[integration:preset-menu-commit]`; do not rerun the now-green Next negative control before final qualification. If native absence fails, it remains blocking; inspect the existing failed-selection evidence before any further change.
