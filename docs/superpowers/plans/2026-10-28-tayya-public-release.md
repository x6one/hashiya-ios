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
- [ ] If RED, implement only the proved ownership fix and run new regression+existing actual route contracts+unchanged Standard/Accessibility real-stroke UI/device. If remaining pixel/Undo fails, analyze retained evidence once, no identical retry or GPU tracing.
- [ ] After all targeted required contracts pass, query actual Apple maximum build, freeze source15+ and run comprehensive gate once (all original/new methods, Maestro3, actual exports, gallery, compatibility, Release/nativeOffice). Keep publicdisabled on any mandatory failure.
- [ ] Use existing Store controller's verified12-image/evidence-bound metadata path; signed IPA/archive, actual processing, exact build attachment, review/AFTER_APPROVAL and Apple state readback. Report official state, not TestFlight readiness as publication.

- [ ] Additional concrete0.4.2→current lifecycle regression: original Notes saved each drawing change; current buffers until tool-end but its dismantle only logs inDEBUG and has noRelease flush (NativePDF already flushes on dismantle). Add `MarginInkLifecycleTests/testSwitchingNotesToTextFlushesUnfinishedInkToItsOriginalFile` using actualMarginPane+MarginPages+PKCanvas delegate callback sequence, then actual handwriting→text teardown and reopen on-diskPKDrawing. Run only thisnewcase/device after the active split-owner baseline ends. IfREDatmissingdiskink, add final synchronous pending-ink flush and detach delegate in actualMarginNotebook.dismantle, preserving end-of-stroke saving otherwise; rerun thiscase+relevantcommit/safety and original UI regressions. No new diagnostics or changedUIthresholds. This is independent of pre-Notes document Undo and delayed live presentation.
