## 2026-10-19 — Rescue audit of c890352; release blocked

- Inspected both requested runs39151098686/39151102579. All four jobs pass67 XCTest and external-byte verification. Full32 UI coverage remains required; Maestro and device packages were skipped. No accepted0.6.0(13) IPA.
- Push phone:28 explicit UI passes; Accessibility fitMarginWidth drag makes zero movement(line966); Standard palette dismissal fails(line1096); paged-margin and light visual journeys each hit240s caps. Do not use the6-test postrestart summary as the full suite result.
- Push pad:31 explicit UI passes; Accessibility Redo5s waiter fails(line1165), then actual count2 equals expected2; original case subsequently hits360s cap and termination fails. Drawing-loss causation is unproven.
- PR phone:30/32 UI cases pass. Native palette outer controller and Done appear, inner segment controls do not(line1049). Navigation Back button/reopening pass, edge pan fails(line1424) with downstream library lookup failures. Same navigation case passes the other3 jobs; blanket gesture-policy causation is unproven.
- PR pad:31/32 UI pass; PowerPoint fixture export completion fails(line184), before the import action. This is a required unresolved failure, not evidence that the Office conversion engine failed.
- PR-phone artifact12146685144 independently SHA256 verified7eeccfffd4f99faf736d49ca2cdae75c10bf54f383fe4332cccde5f32944f4d7. Actual video shows white native palette plus Done. Native log: remote color service requested17:59:45.876UTC, bootstrap succeeds18:00:03.111, scene ready18:00:05.800 after the5s inner-controls waiter. Why system launch took~20s remains unproven. Collection timed out after120s, so the retained partial log is not complete.
- Added a same-repository PR job guard: exact-head push remains authoritative, fork PR verification remains enabled. Existing concurrency still cancels superseded runs within a ref; a skipped internal PR cannot cancel the differently keyed push. Assertions, deadlines, full67/32/3, Office preflight push lookup and package gates remain unchanged. Documentation commit skips CI deliberately; no product fix is claimed.
- Separate diagnostic branch diag/tayya-rescue-navigation source36dcd38c4be4c5e979f0da9da6fa5c3016a80437/run39168607576 adds DEBUG public-edge enabled/direction logging and runs only the unchanged Back/edge/reopening regression on both families. No diagnostic source is release-qualified. Next: inspect actual recognizer state before choosing a minimal navigation correction.
- Fresh baseline Tools13/13 pass locally. Host is Linux without Xcode/simulator; native checks run through GitHub Actions. No Apple upload or PR merge.

## 2026-10-18 — Candidate launch checkpoint; iPad observation experiment not adopted

- Separate iPad comparison25e15f7/run39127831209 completed:67 units and8/9 selected UI pass. Both original ink cases pass341.132/272.106s, four direct mount cases pass and both real light/dark visual/audio journeys pass. AfterTextFocus fails the unchanged5-second joint-mount waiter62.392s. It is not a completed performance repair; do not copy its five nil-object substitutions into the candidate. Evidence metadata is in Verification/Diagnostics/ax-observation-result.json; artifact digest is metadata-only until independently downloaded.
- Candidate product/test change is preserved as f50d54b5d80b3d796a2aeb80641ac6a4f53c9299. This checkpoint adds only the completed diagnostic result and refreshes status before normal full development CI. Retain the public DocumentScreen navigation boundary, the separate Back/edge/reopening regression, and the unchanged32-case full workflow. Native compilation and GREEN remain pending.
- Remaining independent issue: whole-app joint AX snapshots can exhaust the5-second observation after text focus; later correct state does not prove all conditions held before that deadline. Inspect actual samples/native timings, without extending deadlines or removing conditions. The navigation fix does not claim to solve this observation issue.

## 2026-10-18 — Native whole-content pop identified; workspace boundary candidate awaits native validation

- Controlled source79200f0/run39127359591/job117675188379:67 units and the exact10 preceding UI cases pass in the actual original order; unchanged Accessibility ink case fails208.044s at Fit Width pan. External fixture bytes pass. Artifact12136664530 and inner xcresult independently verified; see Verification/Diagnostics/ink-route-prefix-result.json and events.
- Public content-pop identity0x1014a6b10 begins12:45:15.093UTC inside the tool rail with navigation stack1, then changes/ends. The observed rail pan never begins. Isolated same58pt pan succeeds with stack2. This identifies whole-content navigation taking the tool drag despite f87's static dependency; no crash is established in this transition.
- Candidate replaces the failed per-rail helper (already reverted in f4e7cb8) with one stable DocumentScreen background controller. On iOS26 it reserves document pans by disabling only public interactiveContentPopGestureRecognizer while this is the top workspace; it captures/restores the prior enabled state, handles owner/recognizer changes, keeps the policy across a covering native sheet, and restores when leaving/dismantling. Native Back/edge remain untouched in source and must be verified.
- Add one separate ordinary-budget UI regression for native Back, same-document reopening, a real RTL leading-edge pan while ink is selected, and reopening with usable tools. All31 original methods and221 assertions remain byte-identical; full suite now67 units/32 UI/3 Maestro per family. Existing functional deadlines and360s original-case caps unchanged. No other design/model/storage/Office change.
- Fresh13 Tools tests and diff check pass; native compilation and repair GREEN pending. Original RED is the full-prefix reproduction, not a synthetic state hook. Independent lifecycle/test review finds no source blocker; approval is not native verification.
- Preserve distinct f87 cap evidence: Push pad completes actual Fit Width2 just before360cap; PR phone repeatedly waits60s for animation-idle after rotation while main-loop/AX remain responsive. Nil-object comparison does not directly cover these paths. Separate iPad comparison25e15f7/run39127831209 still finishing; do not merge it as a verified performance fix without results. No accepted IPA or Apple publication.

## 2026-10-18 — Isolated original ink test passes; full-suite-history route comparison running

- Diagnostic source1e8a448be41865c22bbcc4812cc757df8c1b5b18 on separate diag/tayya-ink-route: run39126228020/job117671823660 passes the unchanged original Accessibility ink case in242.439s. Artifact12136352405 independently SHA256 c252283d07785e7981eb50b2c03d8078f62c9b524f1ee63dd5e97d3245b7257d; native log collected, no report files collected. This is not a full preflight or a proven repair.
- Actual58pt Fit Width pan matches the failed f87 geometry. Scroll recognizer0x10a748160 begins/changes/ends12:22:24.168–.265UTC; navigation stack remains2, neither observed public pop emits an action. Same native canvas/toolbar frames as f87. The failing recognizer remains unidentified; isolated history and observer effects remain unseparated. Actual screenshot reviewed: red margin stroke visible after Fit Width; accessibility landscape canvas is only44.333pt high, so this is not broad visual acceptance.
- Controlled next source79200f06ac7438dfcb6aa75b4db5e27ed96b1282 runs67 units and the exact10 preceding UI names before the unchanged original case, with original native fixture seeding/byte verification. Run39127359591/job117675188379. Confirm actual scheduling/counts from completed logs before claiming history reproduced. Diagnostic workflow remains distinct and cannot satisfy Office preflight; development full workflow unchanged.
- Local release Tools13/13 and diff check pass. Keep prepared f4e7cb8 rollback/checkpoint rather than accumulating the failed f87 product helper. No accepted IPA or Apple upload. Next: inspect failed-vs-passed gesture sequences, make one evidence-supported repair, then complete exact-source both-family67/31/3 and Office package gates.

## 2026-10-18 — f87 gesture-priority experiment rejected; original UI assertions retained

- Exact source f87bbd3a93a3ad244627985f6999344cd7cb580f: Push39091395832 / PR39091398933 both fail. All four jobs pass67 XCTest. Push phone30/31 UI, sole Accessibility toolbar-disappearance failure. Push pad30 explicit passes plus Accessibility360s case cap/runner restart. PR phone29 explicit passes plus Accessibility toolbar failure and Standard360s cap/restart. PR pad30/31 UI, sole Accessibility joint-mount5s waiter failure. Do not interpret postrestart subtotals as whole31-case aggregates. Maestro and device package skipped; no accepted IPA.
- The public content-pop-to-scroll failure dependency did not repair the native failure. Restore App/MarginNotebook.swift exactly to3e56636 (retain its LTR/dense rail and lazy native picker); no test changes or functional deadline increases. Preserve completed release identity guard1e710260. This restoration is removal of a failed experiment, not a claim that the underlying bug is fixed.
- Push-phone artifact12123652944 independently SHA256 verified dfea4a6548a16eaf4d58cfa9e57ab5a21db782290ea1506721862b4df8783d3a. PID28628 bridge connection logs appear03:07:11.506,03:08:57.972,03:09:09.857. Failing pan triggers a system-gesture state change03:10:36.856, gesture actions and orientation preference changes; cleanup portrait starts03:10:52.276. Connection occurred, but active recognizer identity/priority is not proven. No failure-cycle warning found; do not invent a root cause from absence.
- Separate diagnostic branch diag/tayya-ink-route, commit1e8a448be41865c22bbcc4812cc757df8c1b5b18, run39126228020 observes actual rail/nav gesture classes, identity, state and controller context using DEBUG-only targets/logging. It runs the exact original failing Accessibility case (UITests file SHA29e68ad07b1e16ad3085c1711cfba22214c2d1cd), with unchanged assertions and deadlines. Its workflow/job names are different and it has no device/IPA/Apple stage; it cannot satisfy full preflight. Full workflow on the development branch remains unchanged.
- Earlier3e and f87 native summaries plus precise PR-pad count-observation timing are preserved in Verification/Diagnostics. Drawing two strokes occurs inside the10s observation budget while AX/debug-description work consumes remaining time; no permanent-cache or missing-canvas cause is claimed. Current source restoration passes13 Tools tests. Next: use the focused route evidence to repair the actual boundary, then all67/31/3 and external-byte gates on both families before full native Office IPA/archive-only. No Apple publication/merge.

## 2026-10-18 — Bounded native rail/navigation gesture hypothesis under validation

- Reproduction is the unchanged testIndividualInkTargetsAtAccessibilityTextSize: current3e PR-phone pan starts170.57s; first missing-toolbar query172.75s; library snapshot captured01:36:47.824, before Tear Down177.37s. Archived synthesized event is a58pt pan through the actual toolbar, away from Back/divider. Video changes workspace→library around171→172s. No post-cleanup or AX-type-only explanation fits these observations.
- Hypothesis: iOS26 full-content interactive navigation pop competes with the RTL screen's spatial LTR ink rail. Apple documents interactiveContentPopGestureRecognizer as a leading-to-trailing gesture across the navigation content (https://developer.apple.com/documentation/uikit/uinavigationcontroller/interactivecontentpopgesturerecognizer). This is a hypothesis pending native confirmation, not a proven repair.
- Single bounded candidate: a noninteractive UIViewRepresentable inside the rail content connects its actual ancestor UIScrollView pan with its owning UINavigationController's public content-pop recognizer using pop.require(toFail: pan), only on iOS26+. No delegate replacement, navigation path changes, gesture disabling, user data or canvas changes. Ordinary edge-back remains untouched. DEBUG emits one connection log per recognizer pair. The two already failing original ink tests remain the regression and all31 cases/assertions/deadlines stay intact.
- Local13 Tools tests and whitespace validation pass; Linux cannot compile UIKit. Native build, original-case red→green and full both-family67/31/3 verification remain pending. If the bridge does not connect or the failure persists, inspect evidence/revert this candidate before trying another input change.

## 2026-10-18 — Current 3e56636 results; release identity guard completed

- Fresh remote source 3e56636c1483d0fee0bbd912b2cf148bfeb17f50 supersedes f875 by three commits. Retain its LTR ink rail, compact spacing and lazy native color-picker sheet. Do not reapply the unpublished f875 minimum-pan prototype. User-facing name, Bundle ID, version 0.6.0 and build 13 remain unchanged.
- Push39085878795 and PR39085882683 both complete Failure. All four jobs pass67 XCTest and30/31 UI cases. Push iPhone117552210150 fails Accessibility ink Redo5s waiter and later loses inkToolbar during the compact toolbar pan. PR iPhone117552222248 fails that same toolbar disappearance. Both iPhone Standard ink journeys pass. Both original ink journeys pass in BOTH iPad jobs (Push117552210096, PR117552222394).
- Push iPad's sole failing case is testMarginHandwritingMountsAfterDocumentFit: joint5s snapshot waiter; subsequent handwriting/canvas/no-text assertions pass. PR iPad's sole failing case is testPaperStudioLightVisualCaptureJourney:10s count waiter; subsequent native canvas count2 and5751 visible pixels are recorded. These remain failures, not accepted eventual success. Current paged-margin cases pass all four jobs. Maestro, entrance captures and device packaging are skipped; no current-source IPA.
- Current PR-phone artifact12121960298 independently downloaded and SHA256 verified a9979ae0548a79c9c57c644bfdcb189c7b950ae52aa12b8e14b08144dd113196. Failure hierarchy after the pan contains the library navigation bar and no inkToolbar. Therefore a ScrollView-to-Other query change alone is unsupported. Investigate input/navigation vs teardown timing; no crash or gesture root cause claimed. Recording is sparse VFR and black/missing samples must not be called app termination.
- Completed independent release fix: package_native_app validates canonical project.yml version/build and fixed Tayya Bundle ID before native commands or output creation. Negative tests reproduce stale version, stale build and foreign Bundle ID; positive identity test resolves this checkout even when invoked from an engine folder containing a misleading project.yml. All13 local Tools tests pass. Native package execution still awaits macOS and successful exact-source preflight. The old prepared cf114b5 commit was not used as branch head because its parent predates the three newer commits.
- Next: resolve current iPhone compact-toolbar input loss and the two distinct iPad observation failures without removing assertions or extending functional deadlines, run all67/31/3 and external-byte gates on both families, then build full native Office IPA/archive-only. No Apple publication or PR merge. Older source results below are historical only.

## Historical f875 checkpoint — full iPhone preflight succeeded; unpublished pan prototype superseded

- Exact Push source f8751c831eccd3948c9c93dc6502ce15eb2e53b7: iPhone job117509285928 succeeds with67/67 XCTest,31/31 XCUITest and3/3 Maestro (82.750s audio,233.895s library,143.721s cards). External fixture bytes and real entrance/ReduceMotion recordings succeed. Independently verified artifact12116352063 SHA256a7c3df00d31ebb417c1015c5bb24b9058d2a888eb706100fc3d2aa9a781d35d8; inner xcresult ZIPb67d2cc507bb0187aa9948aef142e0840196e783ba3793c6d65dfa251480be1a. Actual light/dark library, native palette, split handwriting and accessibility recording screenshots reviewed. Entrance movies captured; sampled0.6s frames are OS launch/blank, so visual acceptance of the fold animation remains incomplete. No final IPA.
- Push iPad: all67units pass,29/31UI pass. First palette fails65.864s; Standard mount snapshot starts1.048s and is interrupted5.381s by the existing5s waiter. Later actual model=handwriting, canvas present, TextEditor absent; all5direct mounting cases pass. PR phone all67units,30/31UI pass; one Standard fitMargin no-movement failure. PR iPad all67units;29explicit UI pass records, Accessibility fitMarginWidth failure, and paged-margin240s case cap/runner interruption. Do not use a postrestart subtotal as a complete31-case result. Pads/PRphone Maestro and packages skipped. Both workflows fail overall.
- Verified f875 artifacts: PR phone12116670499 SHA4427dac5912f9e1928fb703eed02e1f621e54368f70ba5e1bf01188c4eb4a76f; Push pad12116027563 SHAdca444ae4b4258842e0b0f275de8cde5ac3e9245a4d91f37e17981543b69e666; PR pad12116312332 SHAf08c0b051efa4c63c27a88df66827b5123866754c6acf7b58e256bbeaf54d824. Full result metadata, errors, crash-collection limitations and inner hashes retained in Verification/Diagnostics/.
- Native pan evidence proves range remains and no picker blocks input: phone offset12.333 with legalrange[-62,12.333], content441.667/bounds429.333; failed16.3ptdrag leaves offset unchanged. Pad offset24.5 with legalrange[0,24.5],content481.5/bounds457; failed24.5ptdrag leaves offset unchanged. Test only a deliberate minimum60pt pan capped40percent of measured viewport, retaining every movement/direction/full44ptcontainment/hittability/edge-tap assertion and8attempts. No new timeout or Apple-threshold claim. Existing red cases are the regression; fresh native verification is pending. Diagnostic print mirrors already-read state without extra AX calls.
- Palette diagnosis remains separate: f875Pad request21:49:21.261, servicePID47871 starts21.472 (~0.20s), connection21.779, sceneactivation26.004, sceneready28.555 (~7.3s). At28.623 native presenter still inFlight with no presented controller/completion. No explicit UIKit rejection warning found. Concurrent39,984 CoreText warnings/1.8s label captures do not establish causation. Do not claim the previous a67510.65s process-start delay is this failure or publish a speculative preload/AX reassignment as a repair.
- Paged PRPad first60s animation-idle stall begins after handwriting switch t44.45, before divider input. Further waits104→164,167→227,227→287 exhaust240s. At the cap, app main thread is idle341/346 spindump samples,0.030 CPU seconds/5s; runner waits for animation quiescence. No busy-layout-loop proof. Screen recording is a60byte pending-attachment error, not video. Investigate mode/focus/control lifetime before altering product code; no timeout increase, animation disabling or test bypass.
- Independent release guard cf114b5b0141a6f3f7e2c960c012a218ca4f5d9c rejects stale version/build/bundle before unsigned packaging, uses own checkout metadata, and passes13local Tools tests. No Apple upload. Native code, identity, version and user storage unchanged in this next pan experiment. Historical next-step proposal superseded by remote3e56636; the deliberate-pan prototype was not published.

## 2026-10-18 — f875 validation in progress; retained native-font and prompt evidence

- Push iPhone f875: all67 unit tests and all31 UI cases pass,0failures, UI1470.788seconds. Build/test and external-byte steps succeed. First Maestro recording lifecycle passes83seconds; remaining flows/job are pending. This does not accept the source on iPad or authorize an IPA.
- Published source f8751c831eccd3948c9c93dc6502ce15eb2e53b7; Push39071291808 / PR39071295697 still running. Partial live results are not release acceptance. PR phone original Accessibility ink passes215.420s, including actual pink PDF/margin pixels and saved counts, Undo/Redo/FitWidth. Its Standard case fails178.055s: fitMargin target x57.6667 remains unchanged after measured drag, native writing viewport startsx62. Push phone Standard passes244.779s. Push pad Accessibility fails65.864s on first native palette; PR pad Accessibility fails304.071s because fitMarginWidth remains x-12.5 after drag. Both failures retain native presenter/UIScrollView state attachments for comparison after job upload. Full totals, Maestro and packaging remain pending.
- Additional independently reviewed a675 evidence: real microphone alert is already visible in the actual32.0s video frame, after the initial observation ended31.30s and before the start waiter ends42.31s. VFR video has a32.16→55.233s frame gap; a seek to33s returns55.233s and must not be mislabeled as33s. This supports the published late-prompt harness correction, not a product-audio fix.
- PR pad previous first-palette request reaches UIKit17:12:59.560; runningboard creates the ColorPickerUIService job17:12:59.592 but first tracks its PID39351 at17:13:10.246, ~10.65s later. No proof that an old brush/width menu overlaps it. New lifecycle instrumentation must distinguish service startup, presentation completion and app state.
- In the same previous failing window,34986 CoreText fallback warnings occur on the app main thread,7 bursts of4998. Label-bearing PDF accessibility captures take0.78/0.82s and emit4998 warnings each; captures excluding Label take0.04–0.06s and emit0. The affected element returns the generated guide heading. This proves repeated PDF text/AX font-resolution work; it does not yet prove which font resources are embedded or that the warnings cause the remote-service delay. Current UIFont.systemFont calls already use public APIs. Do not change UI typography or hide PDF accessibility to suppress the symptom.
- Local early picker.loadViewIfNeeded experiment was not published and was removed: view loading alone does not guarantee remote service readiness and could merely move work to opening the ink toolbar. Await native boundary evidence before choosing another product change. A local diagnostic-only print mirrors the same already-collected native state without additional AX reads; not part of running source. Preserve unrelated pre-existing Store screenshot modification.
- Actual a675 screenshots reviewed:18 per family36 total covering light/dark library/document/split/handwriting/recording/AX Reduce Motion. This is partial visual review of a rejected source, not final screenshot acceptance. Phone landscape custom Done remains outside the native color card while still functional; minor polish deferred per user priority.
- Prepared release-tool commit cf114b5b0141a6f3f7e2c960c012a218ca4f5d9c is saved in GitHub; ref deliberately not advanced while native evidence jobs run. Independent completed release-tool correction: unsigned native Office packaging now rejects stale version/build or another Bundle ID before invoking native tools or creating output. Reuse the existing canonical-version validator and fixed Tayya identity. Resolve project.yml relative to this checkout, not the engine working folder. New negative tests first reproduce all3 missing rejections; a valid-identity test from a foreign folder with a misleading project.yml reaches native validation. No signing/upload or gate changes. Code review finds no blocker; macOS packaging still pending.
- Latest local verification: all13 Tools tests pass and git diff --check passes. Next: retain complete f875 native results, inspect failed/passed toolbar range and presenter events, repair the proven boundary, then repeat all67/31/3 gates and exact-source full Office package. No current IPA or Apple publication.

## 2026-10-18 — a675 full-suite results and bounded native presentation/scroll evidence

- Source a675ee267f4ba57cb50930cf22c5944db3e76f73: Push39051653389 and PR39051657181 both Failure. All67 units pass each of4jobs; external exported fixture bytes pass all4. Every31 unique UI case was scheduled; Push iPad restarts after the Standard ink case exceeds360seconds, so its later19-test summary is not the whole-suite total. Maestro3, entrance captures and device-package skipped. No IPA accepted.
- Push phone29/31 cases pass,3 assertions across2 failed cases: Standard ink fitMargin drag leaves x57.6667 target partly outside x62 native viewport; Accessibility/ReduceMotion recording misses microphone permission. Original Accessibility ink passes276.983s with actual color, pixels, stroke counts, Undo/Redo/Fit. PR phone29/31 pass: Accessibility native palette never appears; Standard repeats identical fitMargin clipping/drag failure. PR iPad29/31 pass: Accessibility native palette never appears; direct DocumentFit fails joint5second mount waiter; original Standard passes298.547s including actual margin ink/Undo/Redo/FitWidth. Push iPad Accessibility repeats fitMarginWidth x-12.5 drag failure353.787s; Standard has actual Undo/viewport waiter failures and a360second cap/runner restart. Do not call these harmless or accepted.
- Notebook creation passes all4jobs, including both iPad runs (46.861s Push,15.550s PR); no notebook-product change justified. Other real touch/relaunch, paged-margin/rotation/relaunch, imports and recording-preserves-workspace cases pass all4; these do not establish complete acceptance or changed-pink process-reopen coverage.
- Retained actual artifacts: Push phone12108473776 SHA2567a58041e1f13f82227ccff5394d1312b47e1418264df9df61e4b4ef0df8d003b and PR pad12109081264 SHA2561909862d8a780c428961c917a7c9ea4f8927482a130e74f34f59e235c9a0b906 independently downloaded/hashed. Inner full xcresult ZIPs independently match retained SHA files: phone7745a5153be25aa30776dc7e3a006d7068f53085fbae3819c7cfda75ba40f328, pad98ab1053128f19923ee2772c30db13c58c4c9c885e02774fdfa8907c6c0cd2ee. Both collection reports contain0 crash reports but system-log collection timed out120s; neither fact rules out all crashes/jetsam. PR artifact metadata uses GitHub's PR merge SHA bbef56b05ea5632c7d5d03e85e37f85115685fb6; authoritative exact-source release gate remains Push.
- Remaining GitHub-only artifact digests: Push pad12109775630 6f21549b0f38ed215088bc17a437e1400d50a796ec38467939c7976055237ebd; PR phone12108239981 e4f3e8ca271c658e8e568976b48303be1a7ac5354c286730c0f9d37bf25f0084. Not independently downloaded/hashed.
- Evidence-based test-harness correction: failed recording tapped at28.65s; initial2second prompt observation ended31.30s; recording waiters failed42.31/52.96s; later Stop input54.65s found the still-pending actual microphone alert, and default handler granted55s. Poll that specifically requested microphone alert during the same existing10second start deadline. Retain actual recording state, advancing duration, level, geometry and stop assertions; no TCC pregrant, fake timer, timeout extension or production audio change. Native verification pending.
- Palette failure video reviewed at actual44.3s frame: color target is activated but no picker visible. Sparse recording gap44.695→57.437s is not proof of exit. Native color-service bootstrap at17:12:59.560 proves a request reached UIKit, not successful presentation. Menu closed17:12:53, ~6s before color tap; do not assume an overlapping menu or a specific presentation race without lifecycle evidence.
- Add DEBUG-only, viewport-test-flag-gated presenter lifecycle ring (12events) and bounded public UIScrollView ancestor geometry (24ancestors/3scrolls). Expose through the existing transparent anchor; attach before/after real toolbar drags and on palette failure. No child/layer/Metal traversal, new functional timeout, canvas/tool/storage change, alternate color or weakened assertion. Native presentation and no-movement causes still unresolved; this is instrumentation, not another claimed product fix. All existing67/31/3 and full Office gates retained. Preserve unrelated pre-existing Store screenshot modification.
- Next: run current exact source, inspect presenter request/window/in-flight/completion/dismantling and native scroll bounds/content/offset evidence; repair the proven boundary, then complete all gates/full Office package/archive-only without Apple upload. Local11 Tools tests and diff check pass; native compile/execution pending.

## 2026-10-17 — Source d894 final evidence; direct native palette presentation candidate

- d894b726777bd253bdc405ab3d10a302cc271aee Push39048906022 / PR39048910224 completed Failure on both families; package skipped. All67 units and all5 direct mounting cases pass in all4jobs (unit durations Push phone7.918/pad8.027;PRphone9.502/pad5.759seconds). No final IPA accepted.
- All4 phone original journeys still fail exact red77 selection after4 actual native palette swipe gestures. Push206.091/197.035s,PR223.166/157.701s. Swipes do not make the lower swatch reachable; do not add more swipes or substitute another color. Push AccessibilityType swipes186.31/188.83/192.36/195.03s; subsequent swatch y687.3 remains below440pt window. This disproves scrolling alone as a sufficient navigation repair in this presentation.
- Push pad originals exceed the240second whole-case cap. First finishes actual margin count1→2, visible pixels, Undo→1 before cap interrupts Redo waiter; later count2/Fit2 evidence is not a completed test pass. PR pad AccessibilityType finishes earlier stages but fails fitMarginWidth toolbar-drag movement at236.850s: target(-12.5,375,44,44) does not move in viewport(0,366,457,61.5). Standard fails joint transition deadline208.883s even though subsequent live canvas=true/text=false; do not call this renewed missing-canvas proof. Full31UI/3Maestro and export prerequisites remain blocked.
- d894 artifacts (GitHub digests only, not independently downloaded/hashed): Push phone12107388147 5b09cf3822b314a9176bf29616f98d566bf3b5802dbdaa68f9335639f1fec2fd; Push pad12107722281 bb9d6d5576d362bab7d51a53bac8fcbd6ea70054e937a4eb0a0fd7bf0f58636f; PR phone12107866093 dbe3b9ed668e803e5d0ab74f2d495b497479b3762dd38d8cff536f211f9f681e; PR pad12107024827 113ac1546e61ca5f6b0f7f60ffc70f6a0860888d9b0038766f27a23d1170cd19.
- Bounded product experiment: remove the SwiftUI sheet/custom child-controller palette container. A transparent44pt background controller anchors the actual UIColorPickerViewController to the color button and presents it natively as a popover with UIKit adaptation. Keep current color binding, native selection delegate, native/interactive/programmatic dismissal, and a44pt Done in the presented controller itself. Guard window attachment/duplicate presentation and reconcile dismissal after in-flight presentation; dismantling clears intent and dismisses. No private view traversal, replacement palette, storage/tool changes or data migration. Own Done overlap/accessibility/native adaptation remain unverified and must be reviewed in real captures.
- Separate evidenced harness change: default whole-case allowance stays240seconds; only the two complete individual-ink journeys explicitly request360seconds. All5/10second functional waiters, counts, pixels, geometry, Undo/Redo/Fit assertions stay unchanged. This permits the full scenario to execute after the real host fix/navigation changes; it does not fix or accept a functional timeout. Any original assertion failure remains red.
- Run one unrestricted full Hashiya scheme67units/31UI per family, without selection/exclusion flags, instead of duplicate preliminary67units/7UI plus full67/31. Unique coverage and exit-zero gates remain; repeated-run/order-isolation coverage is deliberately reduced. Preserve all3Maestro/external bytes/both-family/exact-source Office gates and the60minute job cap. Always retain full TestResults.xcresult ZIP+SHA in NativeResults plus attachments in Screenshots; failure crash collection remains independent.
- Independent code review addressed presentation/dismantling races and found no static blocker; native Done layout/hittability and palette reachability still pending. All11 Tools tests pass;29 workflow shell blocks parse;31UI methods, assertion count and functional timeout literals retained; git diff check passes. No native compilation or readiness claim from Linux. Next: execute the complete candidate, inspect actual images, fix any remaining functional assertion, then full Office IPA/archive-only without Apple publication.
- Additional53e artifact work: Push pad12106807114 independently SHA25660f08cc0017a19a3aac09221ed7c6fe1ddb3bb232f8b4715cd05e5aa866a937e. Focused polling reports snapshot interrupted by waiter at5.291s, later canvas=true/text=false. Width failure actual requested point(816.5,299.5) is inside44pt target; no evidence of old brush-menu overlap or coordinate miss. Sparse VFR video gaps must not be read as earlier app exit; SIGTERM matches test cleanup. System-log collection itself timed out120s, limiting completeness.

## 2026-10-17 — Host replacement reaches native ink; palette navigation and test overhead follow-up

- Source53e08698e4e3bf55b7cb3388523066483647b7e2, Push39046623677 / PR39046627545. Push phone completes67 units0failures8.847s and all5 direct mounting cases (Fit73.338,InkMode36.397,Edited33.196,Focused25.851,Untouched45.106). This is positive native evidence for the retained outer-host mode identity; no whole-app readiness claim.
- Push phone original cases now mount a real PencilKit canvas and remove TextEditor, including rotation. Both finish the PDF visible/color/count/Undo/Redo/Fit steps, then fail1033 at red77 selection in the landscape margin picker (179.064/185.908s). Native AX: picker ScrollView832x368, red77 at y770 outside440pt window. Independently hashed artifact12106681664 SHA25696914087fac6119515f72597460157abfe561f2865231d96ebd795f4c2337c5f. Actual recorded video frame at170seconds reviewed: upper palette rows visible, required lower row offscreen. Native collection reports[], not global crash exclusion.
- Push pad67 units0failures9.959s; Fit105.516,InkMode70.523,Edited64.318,Untouched45.561 pass. Focused70.457 fails joint deadline only (subsequent canvas/text assertions do not fail). First original fails opening Width menu before margin; final artifact detail pending. PR phone original AccessibilityType similarly fails offscreen red77 (225.168s). PR pad both originals reach the240second whole-case execution allowance; later dismiss assertions occur around runner termination and cannot by themselves prove a picker-dismiss product failure. Complete remaining job/artifact evidence must be retained before final interpretation.
- Final53e runs completed Failure on both families; device-package skipped. All67 units pass all4jobs (PR phone10.094s,PR pad7.599s). Both PR families pass all5direct cases; Push pad alone has Focused joint-deadline-only failure. PR phone originals225.168/216.343s fail the same offscreen sample. Push pad Standard reaches actual margin count1→2 and visible-pixel checks but exceeds240seconds during this sequence; no completed Undo/Redo/Fit pass claimed. PR pad originals exceed240seconds; collect timeout/native termination evidence before calling it a product crash.
- Remaining artifact digests (GitHub only, not independently hashed): Push pad12106807114 SHA25660f08cc0017a19a3aac09221ed7c6fe1ddb3bb232f8b4715cd05e5aa866a937e; PR phone12106791813 c87c51fedfb6ca601998187115ea0e058b05c783de69038e17bf4d6a96e53539; PR pad12107046229 61248a70e91fe9c3b543c519f3ff6dd05cb211a30983299e9b310c8a93c05323. Full31UI/3Maestro remain unexecuted after the focused failures; missing external export fixture still reflects that blocked prerequisite.
- New follow-up changes tests only: navigate the existing native palette ScrollView with at most4 real upward swipes if the exact existing red77 is offscreen; still require its hittability, tap it, and verify actual bound color, dismissal, visible ink, stroke counts, Undo/Redo and Fit. Attach before/after swatch frames. No alternate sample, programmatic color, bypass, timeout or acceptance change. Native reachability remains pending.
- Reuse measured toolbar/target rectangles until a real input, refreshing all geometry after every drag. Preserve complete viewport containment, real drag direction/movement, hittability, both44point assertions, edge taps and evidence rectangles. Prior native logs show repeated geometry reads before each tap with no intervening input (e.g. phone Standard Undo80.22→85.85s,Redo90.96→96.72s). Avoid redundant observation overhead without extending the240second case allowance or5second functional deadlines. Independent review found no weakened final condition; native timing remains pending.
- No new product change: retain53e host replacement, PDF650x900 contentSize fix and prior DEBUG Metal crash fix. Keep all67units/31UI/3Maestro/external-byte/full Office device gates, original designs and identity. No accepted IPA or Apple upload. Next: rerun exact follow-up source on both families, require actual margin gestures and complete regression gates before packaging.

## 2026-10-17 — Source34c23be failed; bounded native editor-host replacement pending

- Fresh branch check:34c23be1d423ff468a59b589097e101926d609ca. Push38924030173 and PR38924040465 completed Failure on both families. All67 XCTest pass in all four jobs. Full31 UI/Maestro3/device packaging remain blocked; no accepted IPA.
- Moving editor observation to the consumer did not fix mounting: DocumentInkMode fails on all four jobs; DocumentFit fails mounting on Push phone/Push pad/PR pad. PR phone Fit fails before interaction because SpringBoard reports the application is installing or uninstalling (Busy), not an observed mounting outcome. Push pad Focused fails initial split TextEditor discovery; PR pad Edited fails joint deadline only, subsequent canvas/text checks pass.
- Both original individual-ink cases on all four jobs complete PDF visible/count/Undo/Redo/Fit stages then fail margin mounting. Complete33–39-event traces show handwriting=true, canvas=false, text=true, control.canvas=nil, zero makeUIView calls. The consumer mode callback ran; no trace truncation/eviction. Do not claim an internal SwiftUI cause as proven.
- External-byte verification reports missing Picker-fixture.pdf because the failed focused gate prevents the full suite's exporting cases. This is an unmet prerequisite, not evidence that exported file bytes were corrupted. Preserve the gate.
- Artifacts (GitHub SHA256 digests, not independently downloaded/hashed): Push phone12056734230 81c90aa612a15f1be9572c8e2e0d7fdc12c4dd062717be22377bae38272c67b1; Push pad12057995518 090d1fb979e38aa40e0b2a5bd35e9ba718494845c1ed8bf941a91f72f4124a35; PR phone12057820943 d9d19f94504ae60de15dfbf5d7b8bdecdb2a8451c06e910f51866bd43129e1dc; PR pad12057077738 c2aa01861abef36cc1400f07de02d0a8d1c3255c312c7d1894f687e496404cc7.
- Revert34c's unsuccessful observer experiment to e3cd414. New single experiment: apply mode identity to the outer GeometryReader host. Retain parent store/editor/canvasControl/focus/sheets/page state outside that identity boundary. Only changing text/handwriting rebuilds this native editor host; brush/color/width/page/rotation do not change the identity. This is distinct from the previously failed inner Group identity experiment. Header transient scroll position may reset on a mode switch.
- Next: native67 units, five direct cases and both original ink journeys on each family; retain existing5second joint transition and actual ink assertions, full31 UI/3Maestro/external-byte gates. If unchanged failure, revert this experiment before another hypothesis. No harmless cosmetic work added, identity/version unchanged, no Apple publication.

## 2026-10-16 — Responder cleanup fails minimal reproduction; move mode observation to the consumer

- Source8c5ace24 Push38922051976 phone job117044180402: all67 XCTest pass (0failures,8.497s), including the two real-disk pink-pencil cases. Live focused DocumentFit87.684s and DocumentInkMode61.559s still fail exactly the joint transition/canvas-missing/text-remains assertions. This is not an accepted source; complete UI/Maestro/device validation is absent. Advance after this targeted unchanged failure; superseded runs must not be cited as complete validations.
- Revert the unsuccessful NativePDF responder cleanup completely, matching e3cd414 for App/PDFWorkspace.swift. Preserve unit/storage/test-measurement improvements. Do not combine it with the next experiment.
- Counterevidence from independently hashed3f69 PR-phone artifact: native logs show LassoCanvas0x107aa8400 first responder14:48:41.486, then null/oldPDFDocumentView/newPDFDocumentView during split14:48:48.761–48.871; mode tap14:48:54.218. No evidence old canvas stays first responder through failure. This weakens the prior hypothesis; no causal claim retained.
- Complete trace comparison: failing InkMode pane height198.75→258.75, mode control recreated0x10b64cd00→0x10b6bae90 with stable editor/store/page/canvasControl IDs. Untouched starts258.75 with one control. Passing updates parent→geometry→content→native mode→canvas creation; failed updates child→native mode→parent/onChange with no new geometry/canvas. These correlations justify a bounded dependency experiment, not an assertion of a SwiftUI internal cause.
- Only new production experiment: MarginPane keeps a plain reference to the existing editor; MarginPaneContent remains its observer and owns mode-driven focus clearing. Remove the outer mode read/subscription/onChange so mode changes invalidate their actual consumer. Existing store, editor, canvas controller, focus binding, sheet/page/export lifecycle and geometry layout remain. No new model, whole-pane identity reset or file-format change.
- Validate all67 units, five direct cases, two original journeys then unchanged full31 UI/all3Maestro/external-bytes gates per family. Original5second conditions unchanged. If same failure remains, revert before another hypothesis. User defers minor/cosmetic issues; this functional blocker is still active. No accepted IPA.

## 2026-10-16 — Source3f69f15 completed; minor polish deferred for trial delivery

- Push38918046440 and PR38918055254 completed Failure on both families; device packaging skipped. Push phone direct controls pass40.704/40.213/37.412s; ink-prelude cases fail80.780/63.115s; original PDF stages pass then margin fails180.628/201.948s. Push phone artifact12054084536 digest46af3d2f65fed286c7cf7b1052364188c0bb251d75501dd7df94f9c023d6c645 (GitHub digest, not independently hashed).
- User prioritizes a trial IPA and defers harmless minor/cosmetic issues. Continue fixing the functional handwriting/mounting blocker and preserving files; no cosmetic expansion. Current responder cleanup and new storage cases still require native validation before any fix/readiness claim.

## 2026-10-16 — Source3f69f15 iPad evidence and launch-failure distinction

- PR iPad completed Failure: DocumentFit82.620s/InkMode65.145s fail the three native mounting assertions; Edited67.353s/Focused53.603s/Untouched35.406s pass. Original cases pass PDF stages then fail margin mounting155.590/144.061s. Artifact12054532167 GitHub digest91e1a8cc0c172a77a05ec1a532420ab8316201196883302f23d92bc0aa4a4ae6 (not independently downloaded/hashed).
- Push iPad artifact12054443353 independently verified SHA256 `b3f41ee7e10077dc11a0ef9d3cb1eeeb411cb0dae181ea6205d8547cec1a5cdd`. First four direct cases fail inside app.launch before their named interactions because XCTest cannot acquire a background assertion. They are not executed ink/fit/text contrast outcomes. Untouched passes47.171s; original PDF stages pass, then margin mounting fails223.162/190.893s.
- Native launch investigation: PIDs15025/15733/16607/17274 emit UIKit/scene activity and obtain the app's own shared background assertion, distinct from XCTest's failed request. Later tests explicitly terminate prior apps; RunningBoard records SIGTERM at14:50:56.183/14:51:11.874/14:51:24.290/14:51:36.596UTC. Later nonexistent-process messages follow these terminations. No report files or relevant watchdog/jetsam kill established. Why XCTest acquisition times out remains unresolved; do not label this an app crash or connect it to mounting without evidence.

## 2026-10-16 — PDF responder teardown experiment awaiting native verification

- Follow-up to storage-coverage checkpoint e3cd414b96d0a6d77da04bd3a269caf6db5ceb1a. Only production change: NativePDF.dismantleUIView resigns every registered canvas as first responder before clearing its delegate/removing the overlay provider. Existing pending-ink flush remains first; keeping the delegate through resignation allows synchronous finalization callbacks to persist. No mode/GeometryReader/toolbar/data-format change is combined with it.
- Evidence motivating the experiment: source3f69f15 reproduces missing margin canvas after document ink activation alone, while all three non-ink controls pass on PR phone and the live Push phone/PR iPad groups. Replacing the NativePDF branch during split lacked the explicit responder cleanup already present during document replacement. The prior responder's role is not proven; this is a single reversible hypothesis.
- Required validation: all67 unit tests (including the two new real-storage pink-pencil cases), five direct mounting cases and both original ink journeys on both families, then unchanged full31 UI suite/all3 Maestro flows/external bytes and device gates. Existing5second transition/visible-ink conditions remain unchanged. No native pass claimed from Linux checks.
- Stop/revert condition: if the same native mounting failure remains, remove this cleanup experiment before trying the separate mode-observation boundary experiment. The latter remains unapplied. Completed-stroke evidence does not validate arbitrary asynchronous PencilKit finalization while a view is removed; preserve this limitation during review.
- Last local checks:11 Tools tests pass, workflow YAML/16 Bash blocks/verification JSON parse, git diff check passes. No accepted IPA or Apple upload.

## 2026-10-16 — Source3f69f15: ink activation alone reproduces missing margin canvas

- PR38918055254 iPhone job117030533141 completed Failure. Artifact12054133375 independently downloaded/hashed SHA256 `3b4d43ce591823dd22be3534c2d0d380bfebfcc846ddb30327e0949c0b801692`; PR merge e41e0cc7f285a45ebc6b439b249697ad9b05533b.
- Five direct cases: Edited32.208s,Focused23.767s,Untouched20.657s PASS. DocumentFit45.653s and DocumentInkMode42.878s FAIL deadline/canvas/text assertions. InkMode atomic polls finish1.787/3.798s with modehandwriting,0canvases,1text; Fit1.802/3.725s same. Controls pass first snapshot1.945/1.950/1.578s. This confirms a real transition defect rather than expensive serial AX queries in those cases.
- Complete InkMode40-event/Fit34-event traces retain binding/body/notebookbranchtrue but zeroMarginNotebook.makeUIView calls. No eviction/truncation. Visually reviewed actual C0309ED9-6AE1-4B55-8633-89ACD11A3F36.png: handwriting selected while TextEditor still visible. No palette change, actual stroke, Undo/Redo or Fit is needed to reproduce the defect.
- Both original cases finish visible PDF stroke/count/Undo/Redo/Fit and fail margin mounting only (116.165/115.389s). Crash collection has no reports; that does not exclude all crash/watchdog/jetsam possibilities. Full suites/Maestro remain blocked. Other three jobs are still finishing; preserve their final artifacts before advancing the branch.
- Next bounded experiment: old NativePDF is replaced during split after ink activation; its teardown flushes ink/clears delegates but omits responder resignation present in the document-replacement path. Test this cleanup alone against the five direct cases and both original journeys. Responder ownership is not a proven cause. If failure remains, revert before trying the separate mode-consumer observation experiment. No accepted IPA.

## 2026-10-16 — Pink-pencil storage checks authored; native verification pending

- Add two unit cases using real coordinator commit paths and real disk reload into fresh models for PDF and margins. Retain the black-pen tests. Assert pencil kind, literal pink RGBA, identity transform and original point locations/times/size/opacity/force/angles. This is synthetic stroke storage coverage, not native gesture/rendering proof.
- Run all67 current unit cases before the focused UI groups so their evidence survives an unresolved margin transition. Keep both UI groups running after a unit failure for diagnosis, and require unit, margin and ink statuses all zero before the unchanged full suite. Save unit log and archive its xcresult with failure diagnostics. No acceptance gate removed.
- Linux checks: all11 Tools tests pass,16 workflow shell blocks parse with Bash, git diff check passes. Native compilation and execution of these two new cases remain pending.
- Current published source3f69f15 is being checked in Push38918046440 / PR38918055254. New live evidence: Push iPhone DocumentFit fails80.780seconds with canvas missing and TextEditor still present; PR iPad DocumentInkMode fails65.145seconds with the same native-state assertions. Thus earlier palette/stroke operations are not necessary to reproduce mounting failure. Push iPad initially fails app launch acquiring background assertion; this is distinct from a mounting result. Complete artifacts and remaining cases still pending.
- Final0.6.0(13) remains blocked. No accepted IPA or Apple upload. Changed-color visual Undo/Redo/reopening proof and the complete device/screenshot/Office gates remain required.

## 2026-10-16 — Source3e88692 iPad: document ink measurement passes; original margin journey remains blocked

- Push38849331527 iPad artifact12025186178 SHA256 `e87166fea31346c3e2420690207a085896ccbd333674ee4e9a13ef24c7362e87` contains complete native evidence. Direct Untouched/Focused/Edited mounting cases all pass(103.911seconds), with attached nonzero457×888 native canvases, window/superview present, hiddenfalse/alpha1, modehandwriting and noTextEditor.
- Both original ink cases complete PDF stroke visibility, count, Undo, Redo and Fit, then fail the margin switch at1242(129.539/132.213seconds). Corrected pixel polling captures the first screenshot at1.211/1.227seconds and completes measurement at1.496/1.478seconds, measuring12831/13069redpixels against0baseline. This validates the measurement correction on this source/run, not a renderer fix.
- Original margin failure remains real: modehandwriting, canvasfalse/texttrue, control.canvasnil. All40 trace events retained without truncation/eviction; binding/body/notebookbranchtrue, zeroMarginNotebook.makeUIView events. Therefore the failure precedes native canvas initialization and depends on the earlier document-tools journey; text focus/editing alone does not reproduce it.
- The follow-up retains the joint5second deadline using one public native AX snapshot and adds two focused real-input probes: document ink activation→split, and ink activation→document fit→split. Both probes record identical before/after viewport observations; only the second taps Fit. Fit may leave geometry unchanged on an already fitted page, so retain the viewport evidence before attributing an effect. Passing both would narrow toward the omitted palette/brush/drawing/Undo/Redo steps, not prove one of them responsible.
- Push phone also completes both PDF gesture/count/Undo/Redo/Fit stages, then fails only the original margin switch(164.538/138.301seconds). Its direct cases: Untouched passes36.025seconds; Focused/Edited fail only the joint deadline(65.437/57.907seconds), with subsequent individual canvas/text state assertions passing. Artifact12025346311 reported SHA256 `4dd05289661eb0b0514455662eb8208e1b3ac07688088511fbd34bea9547fa0c` (GitHub artifact digest; full download not yet independently hashed). Full unit/UI/Maestro suites stay blocked.
- Original26 cases and the three direct cases remain; the two added probes bring full XCUITest count to31. All unit/current UI/Maestro/device-package acceptance gates remain required. No production behavior change, IPA or Apple upload in this follow-up.

## 2026-10-16 — Atomic native snapshot for the joint margin transition

- The joint transition still requires all three facts within the unchanged5second waiter: marginMode=handwriting, an actual marginInkCanvas ScrollView, and absence of splitNotes TextView. Replace three serial AX requests per poll with one public `XCUIApplication.snapshot()` and inspect that immutable native hierarchy in memory. This keeps the complete joint condition inside the deadline; it does not move any condition afterward.
- Traverse every snapshot node without a cap or positive early return, match exact identifiers and element types, reject snapshot capture errors, and require one mode control. Both original individual-ink cases and the three direct mounting cases use the same helper. Keep independent real-element state assertions and original failure evidence. Capture timing, visited-node counts and each condition per poll without attachments inside the timed predicate.
- Basis:7994210 phone artifact proves canvastrue/textfalse in every direct variant while two joint waiters fail; three serial AX reads consume the deadline. This is a measurement-path hypothesis pending native validation, not proof that the original full document-tools journey is fixed. Apple documents the public snapshot hierarchy at https://developer.apple.com/documentation/xcuiautomation/xcuielementsnapshotproviding and https://developer.apple.com/documentation/xcuiautomation/xcuielementsnapshot . No private API, production test hook, timeout extension or dropped assertion.
- Independent review found no blocking Swift/semantic issue under the project Swift5 configuration; native SDK compilation and actual before/after results are required. Source3e88692 pixel-polling runs38849331527 /38849336293 must finish before publishing this follow-up to retain their complete evidence.

## 2026-10-16 — Remove AX work from the visibility deadline; retain native acceptance gates

- Source7994210 push38847692072 phone artifact12024561349 SHA256 `3f65a5394f7dacbf79ed5ae0758c4e1fb783f9495caac46ed2f21c17fdfa8a8d` proves all three direct demo→split variants eventually mount the actual attached MarginCanvas and remove TextEditor: Untouched result2, Focused result1, Edited result2; each has modehandwriting/canvastrue/textfalse. The case fails137.809seconds with two predicate deadline assertions, not missing-canvas/text-removal assertions. Focus alone is not a proven fix. The previous full document-tools journey is still distinct and unresolved.
- PR38847697936 iPad live native log reaches Untouched/Focused checks with only predicate-deadline assertions, then exceeds the existing240second total during Edited's fresh launch. Split the new three variants into independent test methods with the same240second limit and fresh app each; no original26 UI method is removed. Full UI suite now29.
- Failed5d iPad evidence below justifies a measurement-cost correction: cache canvas/app geometry and their crop before the gesture, use it for baseline and all timed pixel polls, then assert both frames unchanged after waiting on success/failure. Keep the same real screenshot pixels, >40 threshold and5second deadline. Add cheap per-poll capture/measurement times and pixel counts, attached once after polling. This is not a claimed renderer fix.
- Direct mounting retains the original joint5second predicate requiring modehandwriting, actualcanvas and noTextEditor; it also captures/asserts those states immediately before expensive trace/screenshot evidence. Automatic review rejected moving mode/text checks outside the joint deadline, and that change was reverted before publishing. Both focused groups run even if the other fails; their exit statuses must both be0 before full XCTest/XCUITest, Maestro or packaging. No acceptance gate bypass.
- Native validation of these test changes is pending. No app behavior was changed in this checkpoint. No accepted IPA exists.

## 2026-10-16 — Failed iPad visibility deadline reclassified from actual artifact

- Re-read PR38823719636 iPad artifact12014173968, SHA256 `55692ca4ffcdced4b83cf08f0db2d3f833af15e4e92aece1b605c1113c38fd2f`. The standard case misses the5-second visible-pixel expectation, but its subsequent `RedPixelFailureMeasurement` attachment `CAD49855-9058-45B2-A17F-DA5A34DB31C0.txt` reports beforeRed0, afterRed12913, delta12913 and count0→1. The later failure screenshot contains visible ink. Therefore this is not proof of persistently blank committed ink or a content-extent regression.
- Before/failure diagnostics retain the same current canvas, bounds/content650×900, zoom1, offset0, attached window, stroke inside first512×512tile. Tile contents are present at failure diagnostics, as in the passing accessibility case. Pencil texture loaded23:40:42.989 before stroke end23:40:43.870; the earlier cold texture-loading delay does not explain this attempt. Both passing/failing cases have the same renderer warnings, so those warnings do not discriminate the issue.
- Exact test times: visible-pixel predicate t76.05; AX canvas lookup76.44; triage lookup retries80.32–80.46; failure screenshot83.41; measurement89.22; native diagnostic92.77. No per-poll pixel/timing evidence was recorded, so rendering delay versus slow AX/deadline observation remains unresolved. No timeout/assertion was relaxed. Private-font warning bursts remain unattributed without a requesting stack.
- Current source `799421000862ffca87f8231f7e11f7437e8cc0fe`: push38847692072 and PR38847697936 run the three-arm direct margin mounting regression first. Results pending; no accepted IPA.

## 2026-10-16 — تجربة هوية المحرر فشلت؛ اختبار مباشر لعزل التركيب

- المصدر 5d62053: اكتمل Push 38823711830 وPR 38823719636 بالفشل على الجهازين. بقي الفشل عند LaunchTests.swift:1169 في تبديل النص إلى الحبر، رغم وصول النموذج وbody إلى true. ظهر أيضًا فشل ظهور خط PDF عند 1081 في الحالة القياسية على آيباد PR؛ لذلك نجاح PDF السابق ليس ضمانًا لكل التشغيلات.
- تأكدنا من أن PR اختبر merge d6503ac الذي يحتوي التعديل فعلًا، وليس checkout قديمًا. تغيير Group.id لم يحل المشكلة؛ أُزيل بدل تراكمه. سبب عدم تركيب المحرر لم يُحسم بعد.
- أُضيف اختبار واجهة مباشر جديد يقارن نفس دفتر التجربة في ثلاث حالات: دون لمس النص، وبعد التركيز وحده، وبعد التركيز والكتابة. يقيس تركيب PKCanvasView الحقيقي واختفاء TextEditor، ويحفظ الصورة وtrace؛ لا يغير الاختبارات الـ26 أو مهلاتها أو شروط الرسم. المجموعة الكاملة أصبحت 27 حالة واجهة عند بلوغها.
- يُشغّل اختبار العزل أولًا، ثم اختبارا الحبر الأصليان ثم المجموعة الكاملة وMaestro. فشل العزل يمنع الاعتماد والتغليف كالسابق؛ تُحفظ حزمته ومرفقاته. الأدوات المحلية لا تعادل اختبار iOS.
- بناء Office الكامل على 5d62053 نجح في 38823894857؛ بوابة المحاكيات فشلت، فلم يُنتج IPA ولم تُنفذ الأرشفة الموقعة أو Apple upload.
- التالية: قراءة المقارنة لتحديد هل يختلف السلوك قبل التركيز وبعده عن رحلة الرسم الطويلة، ثم إصلاح مبني على النتيجة. لا إعلان جاهزية، ولا IPA حتى اجتياز كل البوابات.

## 2026-10-16 — الرسم على PDF ناجح؛ عزل تبديل محرر الحاشية

- المصدر 473dcb2، Push 38821072283 وPR 38821079507: الاختباران على العائلتين تجاوزا اختيار اللون ورسم خط مرئي وحفظه وUndo/Redo وFit؛ الفشل المتبقي عند LaunchTests.swift:1169 لتبديل الحاشية من النص إلى خط اليد. لم تُشغّل المجموعة الكاملة وMaestro بعد فشل الاختبار المستهدف. Push آيباد احتاج إعادة تشغيل runner أثناء الحالة الأولى؛ لا يُخفى ذلك ولا يعد قبولًا كاملاً.
- مرفق PR آيفون 12013703341، SHA256 `a924e8a5632610f06154913e346c72a129b39bc4f91bd4a90f7aef86b89aa26b`: الصور الفعلية تُظهر الخط الوردي بعد Undo/Redo، والاختباران يفشلان فقط عند انتقال الحاشية. تهيئة contentSize صححت مسار PDF في هذه التشغيلات؛ إعادة الفتح والانحدار الكامل لا تزال مطلوبة.
- Trace الحاشية يثبت وصول binding=true وتحديث body وتقييم notebook branch=true بنفس editor/store/pane؛ لكن MarginNotebook.makeUIView لا يُستدعى ويبقى TextEditor. التعديل التالي يمنح مجموعة المحرر وحدها هوية مرتبطة بوضع النص/الحبر. لا يعيد إنشاء نموذج الدفتر أو الصفحة أو لوحة التحكم؛ لا تغيير لصيغ البيانات أو الاختبارات أو المهلات. هذه فرضية reconciliation تنتظر إثبات التركيب والرسم في CI.
- بناء Office الكامل على 473dcb2 نجح في 38821396249؛ بوابة الاختبارات منعت IPA. منتقي الألوان نجح في محاولات المصدر 473؛ التأخر البارد السابق محفوظ في PR ولا يثبت إصلاحه الدائم.
- التالية: نجاح تركيب PencilKit واختفاء TextEditor ثم الرسم في الحاشية بعد الدوران، على الجهازين؛ يلي ذلك كل XCTest/XCUITest وMaestro والصور والتغليف. النسخة غير معتمدة ولا IPA ولا رفع Apple.

## 2026-10-16 — تعثر عرض الخط بعد إصلاح انهيار التشخيص

- المصدر c06625e، تشغيل PR 38819037612، آيفون: اختباران مستهدفان، فشلان. بقي التطبيق يعمل وارتفع العداد من 0 إلى 1، لكن صور الخط النهائي فارغة (red pixel delta=0). فشل الاختبار الآخر في إيجاد محتوى منتقي الألوان. لا مجموعة كاملة ناجحة ولا IPA.
- المرفق 12012253524، SHA256 `345a69876eab5361f883ebcfcad9912b19a087acff057a46d6fb9d516bf43571`، يثبت stroke داخل مساحة الصفحة بأداة ولون صحيحين. contentSize للوحة PDF يساوي صفرًا رغم bounds 650×900؛ بلاطات الرسم النهائي بلا محتوى. تأخر تحميل texture القلم نحو 19 ثانية دليل إضافي، وليس سببًا محسومًا.
- تعديل معزول يهيئ contentSize بحجم الصفحة عند إنشاء PKCanvasView، كما تتطلب مساحة الرسم المستقلة؛ لا تغيير للإحداثيات أو الحفظ أو الأدوات أو الاختبارات أو مهلاتها. هذا اختبار لفرضية العرض وليس إعلان إصلاح مثبت.
- بناء الجهاز الكامل مع Office نجح على c06625e في 38819378930، لكن بوابة الاختبارات تمنع تغليف IPA. لا تجاوز للبوابة ولا رفع Apple.
- الخطوة التالية: مقارنة الاختبارين على الجهازين بالمصدر المعدل، ثم المجموعة الكاملة وMaestro والصور والتغليف عند النجاح. تبقى حالة منتقي الألوان ونتائج التسجيل/إنشاء الدفتر بحاجة إلى إثبات جديد.

## 2026-10-15 — السبب المثبت لتوقف الرسم؛ الإصلاح ينتظر CI

- المصدر التشخيصي 37d86ee، Push 38788546525، آيفون: 65/65 XCTest؛ اختبارا أدوات الحبر فاشلان بإجمالي 4 assertions ضمن 26 حالة. إنشاء الدفتر ناجح. لم يكتمل فحص باقي الوظائف وقت إعداد هذا السجل؛ لا يُنسب نجاح قديم للمصدر الجديد.
- مرفق الآيفون 12000617803 يحتوي تقريرَي Hashiya-2026-10-15-190113.ips و190222.ips. كلاهما SIGSEGV/EXC_BAD_ACCESS عند 0x78 في CAMetalLayer.drawableSize، مستدعى من PDFWorkspace.swift:705 ثم دالة فحص presentation layer ثم accessibilityLabel. هذا يفسّر سقوط التطبيق عند محاولة قراءة العداد بعد stroke ظاهر فعليًا؛ لا يثبت وحده سلامة كل مسارات الحفظ.
- الإصلاح المحدود يزيل قراءة drawableSize وpixelFormat من تشخيص AX ويُبقي حقول CALayer العامة. لا تعديل في إنتاج الرسم أو حفظه أو التصميم، ولا حذف لأي assertion. مراجعة مستقلة تؤيد ارتباط الإصلاح بالـstack الفعلي؛ نجاحه النهائي ينتظر اختبار المحاكي.
- يسبق الاختباران المستهدفان الآن المجموعة الكاملة على الجهازين. إذا نجحا تُشغّل نفس مجموعة XCTest/XCUITest ومسارات Maestro الثلاثة؛ لم تُستبدل المجموعة الكاملة بالاختبار المستهدف. تُحفظ مرفقات ونتائج التشغيل المستهدف أيضًا.
- حُسّن جمع الأدلة ليحفظ حزم xcresult قبل سجل النظام ويسجل أخطاء الجمع بدل فقد بقية الأدلة. اختبارات أدوات Python 11/11، وفحص YAML/Python وgit diff --check ناجحة محليًا؛ ليست إثباتًا لنجاح iOS.
- التالية: قراءة نتيجة الاختبارين ثم بقية بوابات المصدر الجديد، معالجة أي خلل مثبت، مراجعة الصور، ثم محرك Office وحزمة الجهاز. 0.6.0 (13) غير معتمد، ولا IPA نهائي ولا Apple upload أو merge.

## 2026-10-15 — تحقيق توقف الرسم على المصدر 033eb4d

- تمت مراجعة سجلات Push 38781681904 وPR 38781686314 والمرفق diagnostics-iPhone رقم 11998216557. نتائج المصدر الحالي: 65/65 XCTest لكل جهاز؛ فشل اختبارَي أدوات الحبر على الجهازين، وفشل إنشاء الدفتر على آيباد PR فقط. Maestro وIPA غير منفذين.
- اللون ونوع القلم والسماكة يصلون إلى PKInkingTool الحقيقي. سجلات PencilKit للعمليتين 28035 و33218 تثبت بدء/انتهاء الرسم وتكوين stroke واحد؛ آخر سجل لكل عملية هو التقاط XCTest لشجرة AX بعد الرسم. احتمال ارتباط العطل بتشخيص AX يحتاج تقرير انهيار؛ لا نعلن أن القلم أو المحاكي هو السبب.
- المرفقات القديمة لا تحفظ crash reports أو xcresult الكامل. أضيف حفظ التقارير الحديثة من المضيف والمحاكي، وسجل PencilKit/PDFKit/RunningBoard/ReportCrash، وxcresult مضغوط عند الفشل. لا تغيير في إنتاج الرسم أو شروط الاختبارات أو التصميم.
- نجحت اختبارات أدوات Python المحلية 11/11 وgit diff --check. لا Xcode أو محاكي في Linux المحلي؛ يلزم CI جديد. آخر خطوة: اكتمال فحص الأدلة القديمة؛ التالية: قراءة تقارير التعطل من التشغيل الجديد ثم إصلاح سببي واختبار أحمر/أخضر.
- لا حزمة 0.6.0 (13) معتمدة، ولا دمج PR أو رفع Apple.

# طَيّة 0.6.0 (13) — سجل المرشح قبل بوابة الاعتماد، 2026-10-14

- تم إعداد ألوان الورق والحبر، أغلفة بمعاينات PDF، هوية الطيّة والترحيب، أدوات متكيّفة، حاشية ورقية، وشريط تسجيل مستقل بمدة ومستوى ميكروفون فعليين. لا تغيير لمعرّف الحزمة أو البيانات أو صيغ الكتابة والتسجيل.
- بقيت اختبارات الواجهة الـ18 السابقة كاملة، مع مسارات Maestro الثلاثة. رحلة صور جديدة تغطي الترحيب والمكتبة والأدوات والتقسيم وخط اليد والتسجيل في الفاتح والداكن والاتجاهين؛ وتضيف تكبير نص إمكانية الوصول وتقليل الحركة. تتحقق من تقدم مدة التسجيل وثبات هندسة الشريط والمستند والحاشية ومساحة الكتابة في الاتجاه الأفقي.
- اختبار جديد يفتح PDF مولّدًا من خارج التطبيق عند بداية باردة مع إعادة علمَي الترحيب والافتتاحية، ثم يتحقق من البطاقة والبحث في محتوى PDF والانتقال بين صفحتيه. يبقى اختيار الملفات عبر Files الحقيقي وفحص البايتات الخارجية بوابة مستقلة كاملة.
- مهلة وظيفة فحوص العائلة أصبحت 60 دقيقة بدل 40، بعد انتهاء محاولة سابقة أثناء إغلاق Maestro؛ مهلة الاختبار الفردي تبقى 240 ثانية، وكل البوابات مفعّلة.
- نجح `git diff --check` وفحص الأدوات المحلي 11/11 في 2026-10-14: خمسة اختبارات أدوات إصدار وستة اختبارات لمسارات ملفات التصدير. لا توجد Xcode أو محاكيات في بيئة التأليف الحالية؛ لم تُشغّل اختبارات Swift أو تُلتقط صور فعلية هنا.
- المصدر `024eee8` اجتاز 65 اختبار XCTest على الجهازين في تشغيلَي push وPR. اختبارا أدوات الحبر لم ينجحا: لوحة ألوان النظام تحجب زر الإغلاق، وعلى الآيباد يبقى النص بعد تحديد خط اليد في التقسيم الأول. بقية اختبارات الواجهة الـ24 نجحت. نتائج assertions: push آيفون4 وآيباد3؛ PR آيفون4 وآيباد2. فحص البايتات الخارجية نجح في تشغيلَي PR، وفشل في push الآيفون لغياب مسار مزود الملفات رغم نجاح اختبار التصدير؛ الصورة الفعلية تعرض الملف داخل مجلد بيانات التطبيق. حفظت السجلات واللقطات الفعلية؛ لم تُنتج أفلام الافتتاحية أو بوابة Maestro أو IPA لهذا المصدر.
- المرشح التالي يضم لوحة الألوان داخل حاوية UIKit واحدة بزر إغلاق فعلي، ويوصل اختيار وضع الكتابة مباشرة بالمحرر نفسه، ويقيس نص التحكم وفق إعداد SwiftUI الفعلي لتكبير الخط. يختبر تغيير اللون وخطًا مرسومًا به، وتبديل مساحة الكتابة الفعلية، ومسار التصدير مع تطابق البايتات. محركات الإحداثيات والرسم والحفظ والصيغ لم تتغير؛ لا اعتماد قبل نتيجة فعلية جديدة.
- مراجعة المصدر المستقل نجحت للمرشح المستعاد؛ لوحة الألوان وتوصيل خط اليد واللون المرئي تبقى بحاجة إلى إثبات المحاكي. نُقل فحص بايتات التصدير نفسه إلى ما بعد XCTest وقبل Maestro، لأن إعادة ضبط المحاكي تمحو الملفات داخل مجلد التطبيق. جميع الاختبارات والأوامر وحدود الوقت باقية.
- يلزم نجاح 65 XCTest و26 XCUITest ومسارات Maestro الثلاثة للعائلتين على المصدر المفحوص، ثم مراجعة الصور والحركة وبناء Office IPA غير موقّع وأرشفة موقّعة دون رفع إلى Apple. هذا السجل يصف مرحلة ما قبل البوابة؛ تُدوّن النتيجة النهائية ورقم المصدر والتغليف في [PR #5](https://github.com/x6one/hashiya-ios/pull/5). سجل المرشح: [Verification/0.6.0-13.json](Verification/0.6.0-13.json).

## السجل السابق

# طَيّة 0.5.1 (12) — متابعة خلل القلم

- تسجيل المستخدم أظهر انتقال الشرائح أثناء تكرار الضغط على القلم. لم تغطّ فحوص 0.5.0 هذا التفاعل المتكرر.
- المصدر الأحمر `4a775db62618f974b9a6bffcbf11cf1337b1c790`، تشغيل `38221932066`: اختبار XCTest للشرائح الأفقية كشف 12 فشلًا متوقعًا في موضع القراءة على الآيفون قبل الإصلاح.
- أكد التتبع في مشهد iOS فعّال أن أعلى العرض في صفحة 4 بينما `currentDestination` يشير إلى صفحة 6. إعادة الانتقال إلى الأخير زادت الانزياح. يلتقط الإصلاح الصفحة والنقطة الفعليتين أعلى العرض قبل تغيّر المساحة ويصحح موضع التمرير بعدها؛ ويتبع عدّاد الصفحة والقلم صفحة القراءة الظاهرة. صيغ الرسم والحاشية والتسجيل ومعرف الحزمة لم تتغير.
- اختبارات الواجهة تضغط القلم 12 مرة في العرض الكامل والتقسيم، وترسم خطوطًا فعلية في المستند والحاشية وبعد تغيير التقسيم والدوران والتكبير وإعادة الفتح. مراجعة مستقلة وفحوص الآيفون والآيباد وIPA لهذا المصدر قيد التحقق. لا يُدّعى النجاح مسبقًا.

## 0.5.0 (11) — 2026-10-12، مرشح «المكتب الهادئ» قيد التحقق

العمل على `work/tayya-calm-workspace` في PR #5، دون تغيير معرّف التطبيق أو ملفات المستخدم أو طلبات مراجعة Apple. مكتبة بأقسام ومراجعة وإعدادات واضحة، تنقل سفلي للآيفون وجانبي للآيباد، معاينات PDF محدودة الذاكرة، واستئناف القراءة. التسجيل لا يفتح الحاشية ولا يغيّر مساحة المستند، وتسجيلات الصفحات السابقة تبقى متاحة. خيارات OCR تطابق اللغات التي يدعمها الجهاز.

المراجعة المستقلة أكدت بقاء حفظ كل تحديث رسم وإعادة تعيين القلم في مسار PDF. اختبار `testDocumentStrokeCommitsLatestInkOnlyAfterToolEnds` على المصدر `37624c5` فشل فعليًا بستة assertions في تشغيل `38209910055`؛ اختبار التراجع والمسح خارج حركة القلم نجح. صار الحفظ عند اكتمال الخط، مع حفظ التراجع والممحاة والتحديد، وتفريغ الكتابة المعلقة عند إزالة عرض PDF. إعدادات القلم ووضع الكتابة تبقى ثابتة خلال تحديثات الحفظ. إصلاح الحاشية عند `ca2b0e4` محفوظ أيضًا.

نجحت أدوات الإصدار المحلية 5/5. لا تُعتمد هذه النسخة قبل نجاح XCTest وXCUITest وMaestro للعائلتين على المصدر نفسه، ثم مراجعة الصور الفعلية. نتائج الفحص النهائية والتغليف تُسجل في PR #5؛ لا توجد مطالبة بإصلاح كل ظروف الجهاز الفعلي أو جاهزية IPA في هذه المرحلة.

## 0.4.2 (10) — 2026-10-09، قيد الاختبار

فُحص الرفض الجديد لـ0.4.1 (9): Apple تطلب الوصول لكل الوظائف وفق 2.1(a) دون تحديد وظيفة. أُضيف اختيار بداية واضح لملفات تجريبية حقيقية دون حساب، وشريط أدوات ظاهر بأسماء وأيقونات. حذف صفحات PDF يحدّث مراجع الكتابة والحواشي والصوت والبطاقات وOCR بمعاملة قابلة للاستعادة بعد الانقطاع؛ التراجع متاح قبل أي تعديل جديد. حذف الحواشي قابل للاستعادة. نقل الملفات إلى الأقسام يخرجها من عرض المكتبة الأساسي. الاختبارات والبناء والرفع لم تكتمل بعد.

## إصلاح الحاشية 0.4.1 (9) — 2026-10-08 (مرفوع ومرسل للمراجعة)

صفحات حاشية مستقلة للنص وخط اليد، ترحيل الحاشية القديمة دون حذفها، تنقّل دائم خارج لوحة الرسم، أدوات قلم مضمنة، تقسيم متكيّف وقابل للسحب، وحاشية بالحجم الكامل تستخدم نفس المحرر. إحداثيات الورقة ثابتة وعرض الكتابة مناسب للمساحة، مع عرض الورقة كاملة والتحريك. قائمة صفحات وعناوين ومعاينات وربط بصفحة المستند؛ إضافة أوراق في نهاية PDF لحماية مراجع الصفحات الحالية؛ البحث والنسخ الاحتياطي وتصدير الحواشي الطويلة يشمل البيانات الجديدة.

المصدر النهائي `e3e0f4da30656265ef9c1d617a9af0ba85c9b73c` اجتاز 34 اختبار منطق و11 اختبار واجهة على كل من الآيفون والآيباد (90 اختبارًا)، مع تغليف الجهاز. نجح البناء الموقّع والتحقق والرفع في التشغيل `37690165583`. دُمج طلب التغيير #3 في `90dff347b0c460faafd77a31605e7502a7ffb40f`.

فُحص رفض Apple السابق للنسخة 0.3.0 (7): طلب المراجع محتوى جاهزًا للتجربة وفق 2.1(a). أُضيف زر «جرّب طَيّة بملفات جاهزة» في إصدار Release، مع دليل PDF ودفتر وعرض تقديمي وحواشٍ جاهزة قابلة للتعديل، دون حساب. حُفظت تعليمات فتحها في ملاحظات مراجعة المتجر وTestFlight.

في 2026-10-08 اكتمل تصنيف التشفير القياسي الإضافي، وفرنسا مستثناة. أُضيف البناء 9 إلى Tayya Beta وTayya Internal، وأُرسل TestFlight؛ الحالة المثبتة **Waiting for Review**. رُبط البناء نفسه بالإصدار 0.4.1 وأُعيد إرسال طلب App Store؛ الحالة المثبتة **Waiting for Review**، بتاريخ 8 أكتوبر الساعة 3:05 مساءً بتوقيت قطر. لا تعني هذه الحالات موافقة Apple أو إتاحة الإصدار الجديد للجمهور بعد. الرابط العام: https://testflight.apple.com/join/bBwnghMX . التفاصيل في Store/release-audit-2026-10-07.md.

## تحديث الدراسة 0.4.0 — 2026-10-04 (مرفوع وينتظر مراجعة TestFlight)

دُمج طلب التغيير #2 بعد نجاح الاختبارات. مصدر الحزمة المرفوعة `d35d22771a4729b6e2c15900088c679ddf0b64b4`؛ دمج المصدر `f28f49f7229da243a02e7e662de59d8488c865a8`. تنظيم ظاهر للأقسام والمحذوفات وشريط جانبي متكيّف، حفظ أصل Office، نسخة احتياطية كاملة واستعادة دون استبدال صامت، خمسة قوالب ورق، تحديد كتابة ونقل/تحجيم/نسخ بين الصفحات، بحث PDF/OpenXML/تعليقات وOCR محلي بفحص دعم اللغة، حاشية مقسومة بالنص وخط اليد، ربط الصوت بالكتابة، وبطاقات مراجعة حسب القسم.

- نجح تشغيل PR [37203531316](https://github.com/x6one/hashiya-ios/actions/runs/37203531316): 25 اختبار منطق و9 واجهة لكل من الآيفون والآيباد، وبناء الجهاز. نجحت بوابة تشغيل push `37203528908` للعائلتين أيضًا بعد إعادة اختبار إعداد Files على الآيفون. روجعت صور المكتبة والحاشية على العائلتين؛ تجربة الصوت وOCR على جهاز فعلي تبقى ضمن اختبار النسخة التجريبية.
- نجح تشغيل التوزيع [37203677730](https://github.com/x6one/hashiya-ios/actions/runs/37203677730)، المحاولة 2: الأرشفة الموقعة والتصدير والتحقق لدى Apple والرفع. أكدت Apple معالجة **0.4.0 (8)** بحالة Complete. أُكملت إجابات التشفير القياسي مع استبعاد فرنسا، وحُفظت تعليمات التجربة وملاحظات المراجع.
- أُضيف البناء 8 إلى Tayya Beta وأُرسل للمراجعة التجريبية؛ الحالة الفعلية **Waiting for Review** مع إشعار المجربين تلقائيًا بعد الموافقة. الرابط العام القائم: https://testflight.apple.com/join/bBwnghMX . البناء 7 ما زال Testing.
- إصدار App Store السابق **0.3.0 (7)** ما زال Waiting for Review. تمنع Apple إضافة بناء بديل إلى هذا الطلب دون سحبه؛ حُفظ الطلب الحالي، ويُقدّم تحديث المتجر 0.4 بعد انتهاء مراجعته. لا يعني الرفع أو الإرسال موافقة Apple.
- أُصلح تجاوز إصدار المشروع بقيم 0.3/7 الثابتة، وأصبحت أداة التوزيع ترفض أخطاء altool حتى عند exit 0 وتتطلب نتيجة XML ناجحة صريحة. تشغيل `37200251554` السابق أعطى نتيجة CI مضللة بسبب خطأ رقم بناء مكرر ولم يرفع حزمة؛ التشغيل المصحح أعلاه موثّق. نجحت 5 اختبارات محلية لأدوات الإصدار.
- سجل الأدلة: [Verification/0.4.0-8.json](Verification/0.4.0-8.json). الأقسام التالية سجل تاريخي يصف حالة المحاولات وقت إنشائها.

## نشر Apple — السجل أُنشئ، البناء لم يُرفع

- أجاز المستخدم نشر TestFlight وApp Store. نجحت الجلسة بعد استئناف تسجيله اليدوي؛ سُجّل معرّف com.ahmadalawi.hashiya للفريق ZUB6SJFQA3 وأُنشئ سجل طَيّة **6818288428**.
- حُفظت النصوص العربية والنسخة 0.3.0 والعنوان الفرعي وتصنيفا Education وProductivity والتصنيف العمري 4+. حالة Apple: Prepare for Submission.
- شهادة Distribution موجودة وتنتهي 2027/09/21، لكن المفتاح الخاص غير متاح هنا. لم يُنشأ اعتماد جديد ولم تُرفع IPA أو تُقدّم مراجعة.
- أُعد مسار أرشفة وتوقيع ورفع اختياري مع بوابتي الخصوصية والتشفير المعطلتين حتى اكتمال التدقيق؛ الافتراضي لا ينشر. لا يعوّض تسجيل دخول المتصفح شهادات التوقيع أو اعتمادات CI.
- نصوص وصور حقيقية وأصلها وحالة المتطلبات في Store/. يبقى بيان الخصوصية والتشفير وروابط الدعم والخصوصية وبيانات المراجع ولقطات الشاشة المطلوبة والتوقيع قبل التقديم.

# طَيّة 0.3.0 (7) — حزمة التجربة متحقق منها

- مصدر التطبيق والحزمة: `d18cc32d4e96e19acd2534992c2557938d910654`. توثيق التسليم اللاحق لا يغير مصدر الحزمة.
- تشغيل الاختبارات [36895436984](https://github.com/x6one/hashiya-ios/actions/runs/36895436984): نجحت 24 من 24 على iPhone 17 Pro و24 من 24 على iPad Pro 13-inch (M5)، كلاهما iOS 26.2 / Xcode 26.2؛ 16 منطق و8 واجهة لكل عائلة، دون فشل.
- نجح اختيار PDF وPowerPoint الخارجيين وPDF من مجلد التطبيق عبر Files الحقيقي، مع رسالة نجاح الاستيراد وفتح المحرر. حُفظ المصدران الخارجيان بزر Save الأصلي في جذر On My device، ثم تحقق CI من SHA256 لبايتاتهما على الجهازين. نجحت كذلك اختبارات القلم وحفظه بعد إعادة التشغيل، والنص والتصدير والتنقل والمكتبة والوسائط.
- تشغيل المحرك [36895436900](https://github.com/x6one/hashiya-ios/actions/runs/36895436900) نجح في بناء تطبيق الجهاز بالمحرك المحلي، ثم اجتاز بوابة نجاح العائلتين للمصدر نفسه قبل التغليف. artifact `11180730113`: `Tayya-native-office-unsigned.ipa`، 132191318 بايت، SHA256 `b8229232b61ef3c03c3c166e229eb0c3e7e01052e2c46f0360f3c9ce7115bd0e`.
- فحص مستقل بعد التنزيل: ZIP سليم، تطبيق arm64 لمنصة iOS device، الاسم طَيّة، الإصدار 0.3.0 (7)، العائلتان 1 و2، موارد المحرك و184 خطًا وإشعارات المصدر موجودة. لا أعلام تجهيز اختبارات DEBUG في ملف Release التنفيذي.
- التوقيع: `CODE_SIGNING_ALLOWED=NO`، نتيجة codesign تؤكد أنه غير موقّع، ولا provisioning profile ولا توقيع في Mach-O. يلزم إعادة توقيع بشهادة وملف provisioning صالحين؛ الحزمة ليست قابلة للتثبيت مباشرة. لم تُنشر في TestFlight أو App Store.
- حذف بطاقة وخيار تجربة Office، وإضافة هوية طَيّة وشعارها وافتتاحيتها. زر «تحويل إلى PDF والكتابة» يستبدل الملف داخل البطاقة نفسها بعد حفظ PDF، ويحفظ بياناته؛ عند الفشل يبقى Office، ولا يُحذف الأصل الخارجي من Files. اختبارات الاستبدال والتراجع وحماية ملفات المستخدم ناجحة.
- روجعت صور المنتقي والمكتبة ورسالة تحويل Office والقلم على العائلتين. صور OfficePreview التقطت Quick Look أثناء Loading؛ اختبار التنقل والوسائط لا يثبت اكتمال عرض Quick Look. تشغيل محرك التحويل نفسه وإصلاح اختيار Files على جهاز المستخدم في هذه النسخة يحتاجان تجربة فعلية؛ ملاحظته السابقة عن نجاح تحويل 0.2.4 لا تثبت جميع ملفات Office.
- سجل قابل للقراءة آليًا: [Verification/0.3.0-7.json](Verification/0.3.0-7.json). يحتفظ السجل بالتشغيل والبصمة وحدود التحقق. الأقسام التالية تاريخ المحاولات السابقة؛ عبارات «قيد التحقق» فيها تصف وقتها ولا تعني أن الحزمة الحالية لم تجتز الاختبارات.

## حفظ مصادر الاختبار مباشرة في Files — قيد التحقق
- المصدر 90824ca، تشغيل 36886149723: نجحت 22 من 24 على كل جهاز، بما فيها المنطق الـ16 وPDF من مجلد التطبيق والقلم والحفظ والنص والتنقل وOffice. لم تنتج IPA؛ بناء الجهاز بالمحرك المحلي نجح ومنعته بوابة الاختبارات.
- تسجيل الآيفون يبين أن Cancel في أعلى المحتوى مصنف Other، فلا يجده استعلام Button. تسجيل الآيباد يبقي نافذة الحفظ وحقل التسمية بعد الضغط على Cancel. زر Save متاح في جذر On My device على العائلتين.
- يحفظ إعداد الاختبار الآن المصدرين مباشرة في ذلك الجذر عبر UIDocumentPicker وزر Save الأصلي؛ لا إنشاء مجلد ولا تسمية ولا إلغاء وإعادة عرض. يتحقق CI من SHA256 للمصدرين في التخزين الخارجي نفسه، ويختارهما اختبار الاستيراد من Files الحقيقي. لا إنشاء host ولا استيراد خفي ولا استبعاد اختبار.
- على الآيباد أثبت سجل 90824ca وهرمية الفشل أن Picker-office استورد بالفعل، رغم انتهاء مهلة قراءة importStatus. ينتظر الاختبار الآن وجود حالة المكتبة عبر waitForExistence بحد 120 ثانية، ثم يتطلب رسالة نجاح وفتح المستند. يبقى الحد الكلي 240 ثانية وبوابة الجهازين كاملة.
- أزيل زر إعادة تصدير مصادر DEBUG لعدم الحاجة إليه. كود استيراد الإنتاج ثابت في هذه الخطوة، وتجربة المستخدم للنسخة الجديدة على جهازه تبقى مطلوبة.

## فصل إنشاء مجلد المصدر عن تصدير الملفين — قيد التحقق
- مصدر 9635aa3، تشغيل 36883921246: السجل الحي للآيباد أظهر نجاح اختبارات المنطق الـ16، ثم إخفاق أول PDF أثناء إنهاء اسم المجلد أيضًا، رغم الضغط على المساحة الفارغة. نجح إعداد التصدير لاحقًا عند عرض نافذة جديدة وجدت المجلد المحفوظ. لا نعتمد هذا المصدر لإخراج IPA.
- أصبح إعداد المصدر مرحلتين صريحتين عبر Files: إنشاء المجلد وتسميته ثم Cancel، والتحقق من callback الإلغاء؛ بعدها فتح تصدير جديد والتحقق من وجود المجلد وحفظ الملفين. إذا لم يحتفظ Files بالمجلد يفشل الإعداد مباشرة. هذا انتقال محدد لإعداد المصدر، ولا يعيد محاولة استيراد الملفات أو يكتب فهرس المكتبة.
- زر إعادة التصدير وشاشة إعداد المصدر كلاهما داخل DEBUG، فلا يظهران في IPA. تُحفظ بيانات طلب التصدير معًا في sheet(item:)، مع فحص وجود ملفين حقيقيين.
- يمتد حد الاختبار الواحد إلى 240 ثانية لاستيعاب عرضي إعداد المصدر ثم الاختيار الفعلي. يبقى نجاح الجهازين وفحص SHA256 للملفين الخارجيين شرطًا للتغليف. مسارات الإنتاج لم تتغير في هذه الخطوة.

## إنهاء التسمية وقراءة نتيجة الاستيراد — قيد التحقق
- مصدر 3f2a143، تشغيل 36880481747: نجحت 22 من 24 على كل جهاز، بما فيها اختبارات المنطق الـ16 وPDF من مجلد التطبيق والقلم وحفظه والنص والتنقل والمكتبة ومعاينة Office. لم تُنتج IPA.
- فشل اختبارا الآيفون الخارجيان عند إنهاء تسمية مجلد المصدر. على الآيباد فشل PDF بالسبب نفسه: بقي DOC.inlineRenameField بقيمة Tayya-test-files ولوحة المفاتيح ظاهرة بعد الضغط على Done. إحداثيات الحدث المصدّر تطابق مركز الزر المرصود، لذلك لا ننسب الفشل إلى إحداثيات خاطئة.
- ينهي إعداد الاختبار الآن التسمية بالضغط على المساحة الفارغة داخل منطقة الملفات بجوار الحقل، ثم ينتظر اختفاء حقل التسمية قبل فتح المجلد والحفظ الأصلي. لا تُنشأ الملفات أو مجلد المصدر من host.
- على الآيباد وصل اختيار PowerPoint إلى المندوب عند 15:12:24. سجل الخدمة وهرمية الفشل يثبتان تم استيراد Picker-office ووجود البطاقة، رغم انتهاء مهلة block predicate في الاختبار. استُبدل بمسند حالة أصلي واحد، ومهلة 60 ثانية؛ ما زال الاختبار يتطلب نجاح الاستيراد وفتح محرر Office.
- عرض السجل الحي على GitHub أظهر جزءًا قديمًا عند جلب ZIPFoundation؛ السجل الكامل يثبت اكتمال البناء وتشغيل الاختبارات. لم يُثبت تعطل جلب المكتبة.

## تصحيح إعداد مجلد Files على iOS 26.2 — قيد التحقق
- آخر مصدر محفوظ قبل التصحيح a6ad23e، تشغيل 36854608461: نجحت اختبارات المنطق الـ16 و5 اختبارات UI على كل من الآيفون والآيباد. فشلت اختبارات Files الثلاثة؛ لم تُنتج IPA من هذا التشغيل.
- على الآيفون أصبح زر Save مفعّلًا بعد إصلاح تمرير URLs، لكن الاختبار بحث عن TextField بينما أظهر سجل الفشل حقل TextView بالمعرّف DOC.inlineRenameField. على الآيباد ضغط إعداد المجلد قائمة More الخاصة بالشريط الجانبي، فظهرت Edit Sidebar بدل New Folder.
- يختار إعداد الاختبار الآن قائمة شريط المحتوى، ويسمّي المجلد عبر الحقل المرصود ثم ينتظر انتهاء تحرير الاسم. تبقى اختبارات الاختيار الفعلي والتحقق من الحفظ وفتح المحرر كاملة، وكذلك فحص SHA256 للملفين الخارجيين.
- هذا التصحيح لإعداد اختبار DEBUG فقط؛ استيراد الإنتاج لم يتغير. اعتماد Files وإخراج IPA ينتظران نجاح الاختبارات على الجهازين للمصدر نفسه، ثم تجربة المستخدم على جهازه الفعلي.

## تمرير بيانات إعداد التصدير قبل عرض نافذة Files — قيد التحقق
- مصدر 214b3d3، تشغيل 36852473096: نجحت اختبارات المنطق الـ16 وبقية UI على الآيفون؛ فشل إعداد الملفين الخارجيين قبل الاستيراد لأن Save بقي معطّلًا، وشاشة إعداد التصدير لم تتلق callback. التسجيل B0BA2A0E-ED2C-4F19-989B-2787E8E9F742.mp4 والهرمية يثبتان حالة الزر.
- تُمرر URLs الآن كطلب Identifiable إلى sheet(item:) بدل تحديث مصفوفة وBoolean في العرض نفسه. يفحص منشئ UIKit وجود ملفين فعليين قبل العرض؛ ينتظر XCTest كون Save مفعّلًا قبل ضغطه، ثم callback نجاح الحفظ. لا يُعتبر مجرد عرض النافذة نجاحًا.
- على الآيباد في 36852473096 فشل إعداد التصدير بالحالة نفسها، وفشل أيضًا اختيار PDF من مجلد التطبيق قبل callback؛ نجحت 21 من 24. لم نعد نعتبر النتيجة الجزئية نجاحًا كاملًا لاختيار Files.
- يُنشأ مجلد الوجهة أيضًا بزر New Folder الأصلي داخل Files؛ لا ينشئ host أي مجلد أو ملف داخل مزوّد Files. هذا يجعل إعداد المصدر كله عملية يستخدمها المزوّد نفسه، مع SHA256 مستقل بعد الاختبارات.
- إعداد التصدير هذا خاص بـDEBUG؛ مسار إنتاج التطبيق لم يتغير في هذه الخطوة. IPA ينتظر بوابة نجاح الجهازين، ولا تُسلّم حزمة من التشغيل الفاشل.

## إعداد مصدر الاختبار عبر الحفظ الأصلي في Files — قيد التحقق
- مصدر 2ec9368، تشغيل 36851175003: أداة Foundation داخل المحاكي أنشأت الملفات وقرأتها بالتنسيق بنجاح. رغم ذلك فشل اختيار PDF وPowerPoint الخارجيين على الآيباد، ونجحت بقية اختبارات الآيباد الـ22. لذلك لا نعتمد التنسيق البرمجي وحده لإنشاء مصادر مزوّد Files في هذا المحاكي.
- لم تُعدّل مسارات استيراد الإنتاج أو تستبعد اختبارات Files. أُزيلت أداة إنشاء الملفات البرمجية؛ يُجهّز CI مجلدًا خارجيًا فارغًا فقط، ثم يحفظ XCTest ملفَي التجربة عبر UIDocumentPicker الأصلي في وضع التصدير وزر Save الحقيقي. يتبع ذلك إطلاق جديد للتطبيق واختيار كل ملف عبر منتقي الاستيراد والتحقق من حفظه وفتح محرره.
- شاشة إعداد الملفات محاطة بـDEBUG ولا تُضمّ إلى IPA. لا تستورد ملفات التجربة الخارجية أو تكتب فهرس المكتبة. يتحقق CI بعد الاختبارات من تطابق SHA256 للملفَي المصدر الخارجيين مع موارد التجربة.
- يمتد حد الاختبار الواحد إلى 180 ثانية ليشمل مرحلتي الحفظ والإدخال الحقيقيتين. تبقى المجموعة كاملة وبوابة نجاح الجهازين للمصدر نفسه.
- هذا يغطي أول استيراد داخل التطبيق من مصدر أنشأه Files نفسه، بعد إعداد المزوّد بالتصدير. لا يثبت تشغيل مزوّد Files فارغ لأول مرة على جهاز فعلي؛ تجربة النسخة الجديدة على الجهاز ما زالت مطلوبة.

## إنشاء ملفات Files داخل المحاكي — قيد التحقق
- مصدر 009e3ce، تشغيل 36848715668: نجحت اختبارات الآيفون الـ24. على الآيباد نجحت 23 من 24، بما فيها PowerPoint وPDF من مجلد التطبيق والمنطق والقلم والحفظ والنص والتنقل.
- فشل أول PDF خارجي بعد الضغط: سجل مزوّد Files يثبت وصول TAP عند 10:34:40، ثم Cannot get URL for item ID localstorage/did=4، وبعده nil url returned from fetchURL. لم يصل URL إلى مندوب التطبيق؛ لذلك لم تُصدر حزمة من هذا التشغيل.
- انتظار عناصر Files أصلح حالة النافذة البيضاء، لكنه لم يضمن صلاحية معرّف الملف الخارجي المصنوع بواسطة rsync من macOS. يُختبر الآن إنشاء المصدر وقراءته بـNSFileCoordinator داخل نظام المحاكي نفسه، عبر أداة Foundation مستقلة لا تُضمّ إلى التطبيق.
- الأداة تكتب ملفَي التجربة فقط في Tayya-test-files، وتتحقق من تطابق البايتات. لا تكتب فهرس المكتبة ولا تستورد الملفات خفية ولا تضغطها قبل الاختبار. جميع اختبارات اختيار Files والقلم باقية، وبوابة IPA ما زالت تتطلب نجاح الجهازين من المصدر نفسه.
- لا يُعد هذا إثباتًا لإصلاح الجهاز الفعلي قبل تجربة المستخدم للنسخة الجديدة.

## نتيجة المنتقي المنسوخ وانتظار واجهة Files
- مصدر 39202e8، تشغيل 36844805749: نجحت اختبارات الآيفون الـ24 كلها (16 منطق و8 UI)، بما فيها PDF وPowerPoint الخارجيان وPDF من مجلد التطبيق والقلم والحفظ والنص والتنقل.
- على الآيباد نجح أول PDF الخارجي وPDF من مجلد التطبيق وجميع اختبارات المنطق والقلم والنص والمكتبة والوسائط. فشل PowerPoint قبل اختيار الملف، أثناء انتظار On My iPad؛ لم يفشل استيراد PowerPoint نفسه في هذه الحالة.
- التسجيل 527ACA26-B224-4DD9-BDDB-3ABE6AE30955.mp4 يظهر نافذة Files بيضاء. سجل الخدمة يبين إنشاء DOCRemoteViewController عند 09:56:12 وready view controller عند 09:56:15، بعد نحو 30 ثانية من فتح المنتقي وقرب انتهاء انتظار الاختبار. لم تكن عناصر Files جاهزة وقت التنقل.
- ينتظر الاختبار الآن ظهور عناصر Files الحقيقية القابلة للضغط (حتى 60 ثانية) قبل التصفح؛ لا يعيد إطلاق التطبيق أو يستورد الملف خفية أو يتجاوز فحص الحفظ وفتح المحرر. كود التطبيق نفسه لم يتغير بعد المصدر 39202e8.
- IPA ما زال ينتظر نجاح الجهازين من المصدر الأحدث.

## منتقي الملفات المنسوخة على SDK 26 — قيد التحقق
- مصدر 59b6505 في 36836979893: نجحت اختيارات PDF وPowerPoint الخارجيين وPDF من مجلد التطبيق على الآيفون. على الآيباد نجح PowerPoint وPDF من مجلد التطبيق، وفشل أول PDF خارجي؛ سجل التطبيق Failed to create a url from bookmarkableString وNSFileProviderErrorDomain -1005 / did=4 قبل completion في fileImporter.
- نستخدم الآن UIDocumentPickerViewController بوضع asCopy=true وملف واحد على SDK 26.2، داخل sheet واحدة وخارج فرض اتجاه محتوى المكتبة. callback مباشر ثم snapshot منسق وفحص وحفظ، دون تحويل bookmarkableString بواسطة SwiftUI.
- بعد نجاح حفظ المكتبة فقط، تُنظف نسخة Documents/Inbox الواردة التابعة للتطبيق. اختبار مستقل يحمي الملف الخارجي حتى لو كان مجلده اسمه Inbox.
- على الآيفون، فشل اختباري النص والقلم قبل فتح المستند لأن كثرة البطاقات جعلت بطاقة التجربة تحت viewport. أضيف تمرير حقيقي محدود للوصول إليها، بما فيه إعادة الفتح بعد relaunch. اختبارات الملفات والنص والقلم لم تُحذف.
- مسار تغليف نسخة المحرك يتابع تغييرات الاختبارات وإعدادها أيضًا. IPA ينتظر نجاح المجموعة الكاملة على الآيفون والآيباد من المصدر نفسه، ولا يُسلّم من تشغيل فاشل.

## إعداد ملفات اختبار Files الخارجي — قيد التحقق
- تشغيل 36835068307 من bafe853 فشل في أول اختيار PDF على الآيفون والآيباد، ونجح اختيار PowerPoint والاختبارات الأخرى. fileImporter بملف واحد لم يكفِ لإصلاح اختبار الملف الموجود داخل مجلد التطبيق.
- السجل يبيّن LocalStorage did=6 غير موجود قبل تسليم URL؛ الملف التجريبي كان يُنشأ عند تشغيل التطبيق في مجلده المنشور عبر File Sharing.
- جهزنا ملفات الإدخال الخارجية في مجلد Tayya-test-files التابع لتطبيق Files على المحاكي قبل اختبارات التطبيق، باستدعاء simctl وrsync، مع تحقق SHA256 للملفات. لا يكتب الإعداد داخل المكتبة أو فهرسها. الاختبار يفتح Files ويضغط الملف ويؤكد رسالة الاستيراد وفتح محرره.
- احتفظنا باختبار مستقل لاختيار PDF من مجلد التطبيق باسم Owned-fixture، إلى جانب PDF وPowerPoint الخارجيين. لم تُحذف الاختبارات السابقة أو تُتجاوز بوابة IPA.
- فرضية العمل: تهيئة/فهرسة مزود الملفات لملف منشأ للتو داخل مجلد التطبيق تؤثر في أول اختيار؛ نجاح التشغيل القادم أو فشله سيحدد ما أمكن التحقق منه. لا يوجد اعتماد لجهاز فعلي لهذه النسخة بعد.

## تحقق طَيّة على iOS 26.2 — 1 أكتوبر 2026
- مصدر 7da4314 تجاوز خطأ type-check في Xcode 26 بعد تقسيم شاشة المكتبة؛ بناء الجهاز مع محرك Office نجح في 36833234702، ولم يُغلّف IPA لأن بوابة الاختبارات بقيت مغلقة.
- تشغيل 36833234766 على الآيفون والآيباد: 15 اختبار منطق ناجحة و6 من 7 اختبارات UI ناجحة. اختيار PowerPoint نجح، واختيار PDF بقي في Files بعد اختيار الصف وضغط Open. لم نعتمد اختيار PDF.
- سجل مزود الملفات أظهر فشل فتح URL وتوقف indexOneBatchInDomain في LocalStorage؛ ضبط إصدار Xcode وحده لم يصلح الاختيار.
- الاستيراد الآن بملف واحد عبر fileImporter، لتسليم الملف مباشرة عند الضغط عليه دون خطوة تأكيد متعددة الاختيار. الاختبار يضغط الملف الحقيقي وينتظر الاستيراد وفتح المحرر؛ لا استيراد مخفي أو تجاوز للبوابة.

# حالة طَيّة — 2026-10-01

## متابعة طَيّة 0.3.0 (7) — قيد التحقق
- اختار المستخدم الاسم «طَيّة — Tayya»، وأبلغ أن تحويل Office إلى PDF نجح على جهازه في 0.2.4 (6)، مع عودة تعذّر اختيار الملف بالنقر داخل Files. نجاح المحاكيات السابق لا يثبت إصلاح جهازه.
- تغيير Files الحالي: fileImporter الأصلي في SwiftUI، أنواع الامتدادات المحددة نفسها، واستيراد ملف واحد مباشرة عند الضغط عليه. يجري التحقق عبر واجهة Files الحقيقية.
- إزالة خيار وبطاقة تجربة Office؛ الترحيل يزيل فقط العنصر المطابق لعنوان التجربة وbytes الملف المضمّن، ولا يمس ملف المستخدم المشابه بالاسم. بيانات المستخدم ومعرّف الحزمة محفوظة.
- زر واضح «تحويل إلى PDF والكتابة». الاستبدال يبقي UUID والعنوان والقسم والمفضلة وموقع البطاقة؛ يتحقق من PDF ويحفظ الفهرس قبل حذف نسخة Office المملوكة للتطبيق. فشل الحفظ أو PDF تالف يبقي الأصل. المصدر خارج التطبيق لا يُحذف.
- هوية ورقة مطوية: حبر أخضر، ورق دافئ، طيّة نحاسية، شعار جديد وافتتاحية قصيرة، ووضع داكن يتبع النظام وReduce Motion دون انتظار الحركة.
- الاختبارات الجديدة تغطي الاستبدال الواحد وحفظ البيانات والتراجع عند فشل الفهرس ورفض PDF تالف والترحيل الآمن للتجربة. تنتظر النسخة نتائج CI قبل تسليم IPA، ولا نشر في المتجر أو TestFlight.

### تشخيص 4538d20 / تشغيل 36827765471
- على iOS 26.2، نجح 15 اختبار منطق لكل جهاز، بما فيها الاستبدال والتراجع والترحيل؛ نجحت خمس تجارب الواجهة السابقة واستيراد PowerPoint على الجهازين. فشل اختيار PDF ومنعت بوابة الاختبارات IPA.
- فحص تسجيل الآيفون والحدث أكد اختيار PDF والنقر على Open في موضعه الصحيح. مزود LocalStorage أخفق قبل callback: NSFileProviderErrorDomain -1005، NonExistentItemIdentifier=did=5؛ لا مشكلة استيراد داخل LibraryStore في هذه المحاولة.
- بدل مسار directoryURL للاختبار، تُنشأ الملفات مبكرًا بكتابة منسّقة ويختارها الاختبار بتصفح Files الحقيقي. يستعمل التطبيق fileImporter الأصلي بدل UIKit representable. لا يُعد الإصلاح معتمدًا قبل إعادة التحقق.
- نجح بناء تطبيق الجهاز المحلي عند 4538d20، لكن التغليف مُنع بسبب إخفاق الاختبارات. تصحيح تباين زر التحويل في الوضع الداكن ورسائل إذن الميكروفون واسم ملف التصدير ضمن المتابعة.

### تشخيص 3f2e2da / تشغيل 36829670931
- نجح 15 اختبار منطق وخمس تجارب واجهة سابقة واستيراد PowerPoint على الجهازين. إخفاق PDF بقي قبل التسليم: LocalStorage did=6 وNSFileProviderErrorDomain -1005، رغم التصفح الحقيقي والكتابة المنسّقة للملفات التجريبية. native fileImporter وحده ليس إصلاحًا معتمدًا.
- كشف السجل أن البناء بـXcode 16.4 بينما المحاكي iOS 26.2؛ يجري توحيد أداة بناء التطبيق والاختبارات إلى Xcode 26.2. محرك Office يحتفظ بأداة تجميع أرشيفاته وcache القديم، ثم يُربط التطبيق بالـSDK الأحدث. لا يُنسب النجاح لهذا التعديل قبل نتيجته.

## اعتماد الاختبارات السابقة عند a5a36a3
- تشغيل 36822168445: نجحت المجموعة كاملة على iPhone 16 Pro ومحاكي iPad: 11 اختبار منطق و7 اختبارات واجهة لكل جهاز، دون إخفاقات.
- اختيرا PDF وPowerPoint عبر Files الحقيقي، وسُلّما للتطبيق، وحُفظا في المكتبة ثم فُتح محررهما/معاينتهما. لا استيراد خفي في الاختبار. طلب أنواع النظام للامتدادات نفسها مع asCopy=false اجتاز الاختيارين؛ لا يُنسب النجاح إلى تجربة asCopy=true السابقة التي فشلت.
- نجح رسم القلم باللمس وحفظه بعد relaunch، والتنقل أثناء الرسم، والنص وحفظه وتصديره، والمكتبة والأقسام والحذف، ومعاينة Office واستخراج وتشغيل الوسائط.
- تشغيل Office 36822168606: نجح المحرك والربط وبناء تطبيق الجهاز وموارده، واجتازت بوابة الاختبارات للـcommit نفسه. اكتمل تغليف IPA وفحصه النهائي: ZIP سليم، Mach-O arm64 لمنصة iOS device وعائلتي الجهاز [1,2]، وموارد المحرك و176 خطًا موجودة.
- التحويل المحلي داخل نسخة الجهاز 0.2.4 (6) تجريبي؛ نجاح البناء والربط لا يثبت تحويل DOCX/PPTX/XLSX فعليًا. يحتاج هذا اختبار جهاز بعد توقيع صالح. نسخة المشروع العادي 0.2.3 (5) تبقى Quick Look.
- لا نشر في TestFlight أو App Store، ولا شهادة أو provisioning profile في البناء. IPA الناتج غير موقّع تمامًا (codesign verify exit 1: code object is not signed at all)، ودون embedded.mobileprovision؛ يحتاج شهادة وprovisioning profile صالحين قبل التثبيت.

### ملف التجربة 0.2.4 (6)
- `Hashiya-native-office-unsigned.ipa`، الحجم 130395636 bytes.
- SHA256: `a67663e4ca85c8993f5aaea04b9847cfe68d2159c201802f114476a9dcb69ffe`.
- [تنزيل artifact من تشغيل Office الناجح](https://github.com/x6one/hashiya-ios/actions/runs/36822168606/artifacts/11144170939)، محفوظ 14 يومًا من 2026-10-01. يضم IPA وSHA256 وتقرير التوقيع.
- سجل التحقق المختصر في `Verification/0.2.4-6.json`. كود IPA عند a5a36a3484d99e6a52b070089f8e30e174e4d701؛ تحديث التوثيق اللاحق لا يغيّر الكود المختبر.
- نجح أيضًا بناء IPA العادي في device-package من 36822168445. المطلوب تجربة المحرك المحلي في IPA 0.2.4 (6) بعد التوقيع، لا اعتبار نجاح المحاكيات إثباتًا لتحويل Office على الجهاز.

## سجل المحاولات السابقة (النتيجة المعتمدة أعلاه)

## تشخيص Files بعد وضع النسخ
- تشغيل 36820733356 عند e8ac241: نجحت 11 وحدة وخمس تجارب UI السابقة على الجهازين؛ فشل اختيار PDF وPowerPoint مع asCopy=true. هذا التغيير ليس إصلاحًا معتمدًا؛ أُعيد asCopy=false.
- حُدّد طلب المنتقي بأنواع النظام للامتدادات السبعة نفسها، بدل مرشحات content/data العامة. الصور تظهر ملفات Office متاحة وتستجيب للمس، لكن ذلك وحده لا يثبت مطابقة النوع الذي يستعمله مزود Files عند فتحها.
- يرفق CI سجل عملية التطبيق ومزود الملفات وDocumentManager عند الفشل، إلى جانب الحدث والصور والتسجيل، لتحديد فشل التسليم قبل callback.
- بناء Office في 36820733271 نجح؛ بوابة الاختبارات منعت IPA. يراقب workflow الآن تغييرات App وproject.yml أيضًا حتى لا يبقى بناء المحرك منفصلًا عن كود التطبيق الذي ينتظر اختباره.

## متابعة الاستيراد والتحويل المحلي
- تشغيل 36817888565 و36818017624: نجحت 11 وحدة واختبارات PDF والقلم والحفظ والنص والتنقل ومعاينة Office والوسائط على الجهازين. فشل اختيار PowerPoint وحده؛ منع ذلك IPA العادي والمحلي.
- فُحص تسجيل الآيفون وSynthesized Event: اللمس عند (44, 532) يطابق صورة PowerPoint، ويظلّل صفه فعلًا؛ Files لا تنهي اختيار الملف. لذلك ليس هذا الفشل خطأ موضع ضغط.
- يعاد التحقق الآن بمنتقي الاستيراد asCopy=true في sheet واحدة، بدل فتح المصدر في موضعه. يحتفظ LibraryStore بنسخته الخاصة بعد الفحص والحفظ كما سبق. لا يدّعي هذا التعديل نجاح الاستيراد قبل نتيجة CI.
- دمج مصدر التحويل التجريبي من work/native-link-probe؛ يظل مشروع المحاكيات العادي Quick Look. مشروع الجهاز المولد يفعّل HASHIYA_NATIVE_OFFICE ويقدم زر إنشاء PDF مستقل للقلم والنص، دون تعديل الأصل.
- نجح الربط وبناء تطبيق الجهاز مع المحرك والموارد في 36817106087 و36818017626. التحويل الفعلي DOCX/PPTX/XLSX يحتاج جهازًا بعد التوقيع؛ بناء التطبيق لا يثبت تشغيل التحويل.
- التحويل يستعمل snapshot خاصًا وqueue واحدة؛ Batch يمنع حوار تحميل غير مراقب، والماكرو معطّل. يجمع الناتج PDF مستقلًا، يفحصه ويستورده في قسم الأصل ثم يفتح أدوات PDF.
- IPA المحلي المتوقع 0.2.4 (6)، مع manifest المصدر وإشعارات upstream وSHA256 وتقرير التوقيع. تغليفه مشروط بنجاح اختبارات الآيفون والآيباد للـcommit نفسه. لا شهادة أو provisioning profile؛ يحتاج توقيعًا خارجيًا صالحًا ولا يمكن تثبيته مباشرة. لا نشر في TestFlight أو المتجر.

## متابعة 2026-10-01 — نتائج مثبتة وبوابات متبقية
- commit a6e7386 يوسع قبول أنواع Files إلى PDF وcontent وdata، ويضيف فحص أنواع الامتدادات السبعة. نجح الفحص على الآيفون والآيباد؛ تغيير الضغط إلى صورة المستند سبّب فشل PDF أيضًا، فأعيد ضغط الخلية في 98dae32.
- تشغيل 36815853793 على الآيفون: 11 اختبار منطق ناجح، واستيراد PDF فعلي ناجح، وبقية تجارب القلم والحفظ والنص والتنقل وOffice/الوسائط ناجحة؛ اختيار PowerPoint ما زال يفشل داخل Files. لا تسلّم IPA اعتمادًا على هذا التشغيل.
- commit 2ba06fc يختار وضع القائمة الأصلي داخل Files في اختبار الاختيار، ثم يضغط صف المستند الحقيقي. لم يُعتمد الاختبار حتى تكتمل نتيجة التشغيل.
- Office: اكتمل التجميع في المحاولة الثانية من 36723900717. فشل التغليف بسبب ترتيب معاملات lipo؛ أصلح في a6e7386، بما فيه فحص معمارية IPA.
- تشغيل 36814993039 نجح واحتفظ بمرشح arm64: artifact 11141296342، 266011214 bytes. فُحصت SHA256 لكل مكتبة/كائن من 368 input؛ المصدر 124ecf55b0f0969b7859d2f803f0bc3a0049a4dc. وجود المكتبات وحده لم يثبت الربط.
- فرع work/native-link-probe: فشل الربط الأول في 36815526018 بسبب عشرة رموز NSS/OpenSSL متعارضة. أصلح 40f4b09 بعزل تعريفات ومراجع NSS باستخدام llvm-objcopy دون تجاهل linker errors. نجح الربط arm64/iphoneos في خطوة Link COKit من 36816343696.
- أضيفت رؤوس feature configuration وcomponent mapping وإشعارات upstream إلى الحزمة، حتى تكون قابلة للاستهلاك خارج شجرة المصدر.
- commit 1227987 على الفرع الهندسي يجهز التحويل التجريبي داخل التطبيق: محرك واحد على queue متسلسلة، snapshot مؤقت للمصدر، PDF مستقل، فحصه ثم استيراده وحفظه في المكتبة، وفتح أدوات PDF. مشروع الجهاز المولد يربط المحرك وموارده. لم يُعتمد بناء التطبيق أو تشغيل التحويل بعد.
- لم ينتج IPA جديد معتمد بعد. ما زال التوقيع الخارجي بشهادة وprovisioning profile صالحين مطلوبًا؛ لا نشر في TestFlight أو App Store.

## متابعة 0.2.3 (5) — غير معتمدة حتى اكتمال الاختبارات
- بدأنا من ac3678f2576f1221f2cbd9cb9f4215a58d59f0ec، وراجعنا README وSTATUS وآخر commits وتسجيلات الفشل على الآيفون والآيباد.
- تشغيل 36751414255: اختيار PDF وPowerPoint فشل؛ التسجيلات تظهر بقاء Files مفتوحة، ولا importStatus. اختبارات القلم والحفظ والنص والتنقل ومعاينة Office والوسائط نجحت. انتهى التشغيل cancelled عند بدء التعديل التالي بعد حفظ تشخيص الجهازين؛ نتائج الاختبارات نفسها متاحة في diagnostics.
- commit 96d7682adda867ad682fb1590d503cd51cebf334 جرّب asCopy=false وحده. تشغيل 36753270819 لم يصلح اختياري Files؛ لا تعتبر فتح المصدر وحده حلاً.
- commit 0fa8a31290aafa6782127d459a9680ee6c3a0727 يعيد المنتقي المباشر في sheet واحدة وضغط خلية المستند كما في المسار الذي نجح سابقًا، مع احتفاظ المكتبة بالنسخة الخاصة.
- DocumentImport ينسّق قراءة مزود الملفات بـNSFileCoordinator، ويأخذ snapshot محليًا ويفحصه خارج main actor. لا تضاف بطاقة للمكتبة قبل حفظ فهرسها؛ فشل حفظ الفهرس يحذف النسخة الخاصة ويبقي الأصل. أضيفت ثلاثة اختبارات لاستيراد async وحفظ الأصل والتراجع عند فشل الحفظ ورفض المصادر المفقودة أو التالفة.
- تشغيل التحقق الحالي: 36754883405. لم يعتمد اختيار Files ولم يُسلّم IPA جديد بعد. أبقينا اختبارات القلم وكل الاختبارات السابقة وبوابة بناء IPA بعد نجاح الجهازين.
- بناء الجهاز يرفق Hashiya-signing.json وHashiya-unsigned.sha256، والإصدار مميز بـ0.2.3 (5). لا توجد شهادة أو provisioning profile؛ IPA الناتج مخصص للتوقيع الخارجي وليس للتثبيت المباشر.

### استئناف Office
- محاولة 1 من 36723900717 انتهت failure لأن خطوة التجميع تجاوزت 210 دقائق؛ آخر الملفات كانت sw/source/uibase، ولم يظهر compiler error في السجل. لم ينتج مرشح ربط مكتمل، لذلك لم يدمج المحرك في التطبيق.
- نجح حفظ checkpoint: native-ios-124ecf55b0f0969b-v2-a8be4f9af0a2-36723900717-1 (2146366207 bytes compressed).
- أعدنا job الفاشل لاستكمال البناء من checkpoint في محاولة 2؛ يجب التحقق من رسالة Cache restored والتجميع والـmanifest والموارد قبل الدمج.
- تشخيص المحاولة الأولى: artifact 11115283522. ما زال Office في التطبيق Quick Look فقط، دون كتابة فوقه أو تحويل محلي إلى PDF.

## النسخة المرشحة 0.2.2 (4)
المستودع أصبح عامًا بموافقة المستخدم. رسالة GitHub أكدت أن فشل بدء المشغّلات السابق مرتبط بالدفع/حد الإنفاق. بعد تغيير الرؤية بدأت المشغّلات فعليًا، فلا تعِد تشخيص العائق السابق.

### إصلاح الاستيراد والتحقق
- استيراد الملف يبدأ من callback اختيار UIDocumentPicker مباشرة، بدل انتظار onDismiss مع URL مؤجل.
- الاختبار يفتح منتقي Files الحقيقي ويضغط ملف PDF، ثم يتحقق من رسالة النجاح وفتح محرر المستند؛ لا يوجد استيراد خفي.
- تشغيل 36717218785 أثبت نجاح الاستيراد على محاكي الآيفون والآيباد. نجحت أيضًا اختبارات المكتبة والنص والتنقل ومعاينة Office والوسائط، وجميع اختبارات المنطق السبعة.
- فشل تشغيل 36717218785 كله بسبب اختبار القلم الجديد: PDFKit لا يكشف overlay Canvas في شجرة Accessibility، فتوقف قبل تنفيذ السحب. هذا لا يثبت نجاح أو فشل القلم.

### القلم
- تفعيل PDFView.isInMarkupMode وتنشيط Canvas للصفحة الحالية، مع drawingPolicy = anyInput ودون تمرير داخلي للقماش.
- يعرض زر القلم عدد الخطوط المحفوظة كقيمة Accessibility.
- الاختبار المعدل يسحب على PDF الظاهر، يتحقق من زيادة العدد بعد الكتابة الفعلية، ثم يعيد فتح التطبيق للتحقق من الحفظ.
- تشغيل 36719468440 فشل بعد السحب الفعلي: عدد الخطوط بقي صفرًا على الآيفون. لا تدّع إصلاح القلم بعد.
- إصلاح ترتيب ربط overlay provider قبل تحميل المستند أثبت نجاح رسم القلم باللمس وحفظه بعد relaunch على الآيفون والآيباد في 36720401781، commit 8f8402c5823d67ef6a4ce83cfb481fa3df31fd3c.
- نجحت مجموعة اختبارات الآيباد كاملة. على الآيفون نجح التصدير والقلم، وفشل اختبار اختيار PDF لأن نافذة Files بقيت مفتوحة؛ لا callback ولا رسالة importStatus.
- صفحة GitHub عرضت سجلًا متأخرًا أو ناقصًا أثناء التشغيل. السجل المكتمل أكد أن التصدير نجح ولم يتوقف؛ لا تشخّص تعطل التنفيذ من آخر سطر مرئي وحده.
- تشغيل 36726085368: اختبارات المنطق السبعة وخمس تجارب UI (المكتبة، الإنشاء، النص/التنقل، القلم/الحفظ، Office/الفيديو) نجحت على الآيفون والآيباد. اختبارا اختيار PDF وPowerPoint فشلا على العائلتين؛ لا تعتمد الاستيراد بعد.
- شريط التنقل يظهر أعلى الصفحة عند تفعيل القلم حتى لا يغطيه PKToolPicker؛ اختبار الوصول للأزرار أثناء الرسم نجح على العائلتين.
- تغيير ignoresSafeArea صحح إحداثيات Files في شجرة الوصول لكنه لم يحل اختيار الملفات.
- commit c700a5643186a1dc17b1c900669afa09ba1b0b2b يستبدل تضمين UIDocumentPicker بعرض UIKit modal كامل من Presenter في viewDidAppear؛ تشغيل 36750139680 فشل في اختبارَي Files على العائلتين، وباقي الاختبارات نجحت؛ تغيير عرض النافذة وحده لم يحل المشكلة.
- commit 957233dce948441d121de1b66efb8a2c51cd0542 يضغط اسم الملف عبر عنصر Accessibility بدل إحداثيات الصورة، مع الاحتفاظ بتسجيلات mp4 في التشخيص. تشغيل 36751414255 جارٍ؛ افحص النتيجة والتسجيل إن فشل قبل تعديل الاستيراد مجددًا.
- جهزت fixture PowerPoint واختبار Files فعليًا، ثم جعلت منتقي الملفات fullScreenCover مع منع السحب لإغلاقه، والاختبار يلمس صورة المستند بدل مركز الخلية. يلزم نتيجة CI للتغييرات الأحدث قبل تسليم IPA.
- أضيف انتظار bootstatus ومهلة 120 ثانية لكل اختبار؛ لم يُحذف أي اختبار.
- بناء IPA مرتبط بنجاح الاختبارات على العائلتين، ويُمنع تلقائيًا عند فشل أي اختبار.

## Office: العائق الأساسي لم ينتهِ
حاليًا العرض عبر Quick Look فقط. لا يوجد تحرير قلم أو نص على Office، ولا تحويل Office إلى PDF في التطبيق. احتفاظ الأصل واستخراج الفيديو إلى مشغّل مستقل موجودان ومختبران بملفات تجريبية.

- تشغيل المحرك الأول 36717328797 انتهى cancelled بعد مهلة البناء. تشغيل 36723900717 (job 109931090383) يستخدم workflow الأحدث ويحفظ المكتبات والموارد ونقطة استئناف عند توفرها. في آخر فحص كان لا يزال يبني C++؛ لم يُنتج مرشح دمج معتمد بعد.
- المصدر الرسمي مثبت عند 124ecf55b0f0969b7859d2f803f0bc3a0049a4dc. الواجهة الجديدة COKit وليست LibreOfficeKit.
- عُدّلت workflow للبناء القادم: GNU Make، أربعة عمال، تعطيل الرموز، حد أطول، واستعادة وحفظ checkpoint محدد بالمصدر وXcode (حتى 8 GiB). لا يغير هذا تشغيل البناء الجاري.
- workflow تجربة هندسية يدوية؛ لا تولد IPA ولا تعني دمج المحرك في التطبيق. النسخة الأحدث تحتفظ أيضًا بمكتبات arm64 والموارد وmanifest كمرشح ربط محدود بـ256 MiB مضغوطًا، لتجربة دمج لاحقة. يلزم التحقق من المنصة والربط والتشغيل قبل الاعتماد.
- المطلوب بعد نجاح التجميع: الموارد وتهيئة COKit، ربط مكتبات arm64، ثم تجربة تحميل DOCX/PPTX/XLSX وتصدير PDF داخل التطبيق على جهاز فعلي. لا تختصر هذا إلى إضافة مكتبة غير مختبرة.
- المحاكيات لا تكفي للتحقق من محرك arm64 للجهاز؛ حافظ على اختبارات PDF والمحاكيات أيضًا.
- التحويل لصفحات ثابتة لا يحتفظ بحركات PowerPoint أو الفيديو داخل PDF. احتفظ بالأصل والوسائط منفصلة، ولا تعد بمطابقة كل الخطوط أو الملفات.

## قيود التسليم
- IPA غير الموقّع يحتاج توقيعًا صالحًا قبل التثبيت. لا تستخرج شهادات أو أسرار مشاريع أخرى.
- المستخدم يريد تجربة IPA قبل TestFlight؛ لم يؤذن بالنشر الآن.
- اختبار جهاز فعلي لا يزال مطلوبًا للأقلام والتسجيل والاتجاهات والتكبير.
- تحويل خط اليد إلى نص والتبويبات المتعددة والأشكال الهندسية غير مكتملة.
- لا تتعامل مع IPA 0.2.1 القديم كأنه يتضمن إصلاحات 0.2.2.

## 2026-10-01 — Signing setup and upload blocker

- Apple record: **طَيّة — Tayya**, Apple ID **6818288428**, bundle com.ahmadalawi.hashiya, team ZUB6SJFQA3. Arabic metadata, categories and 4+ questionnaire saved. Prepare for Submission; TestFlight has no builds.
- New approved Apple Distribution certificate and Tayya App Store profile created. Certificate/private-key match, identity, expiry and App Store entitlements verified offline. Three signing secrets confirmed in GitHub Actions. No private signing material is committed or included in artifacts.
- One-time downloads for Tayya Upload and its same-permission replacement Tayya Upload CI returned no file/event. Private keys are unavailable. Stop generating additional keys; owner assistance is required to recover an upload credential. Unrelated app credentials were not reused. See Store/signing-status.json.
- Added privacy manifest for verified file metadata and elapsed-timer reasons. Store/privacy-audit.md and Store/encryption-audit.md retain findings and open questions; both publication gates remain false.
- Workflow supports sign_archive=true, publish_to_apple=false using only three signing secrets. This generates an App Store signed inspection IPA without uploading. Publishing still requires all six secrets and completed audits. No signed archive has passed macOS verification yet.
- Simulator selection prefers current iPhone Pro Max / iPad Pro 13 for real Store captures. Prior 48 tests passed at d18cc32; the changed source needs a new run.
- App Store signed IPAs require Apple processing and TestFlight/App Store distribution, and are not directly installable. No review submission or publication is claimed.

Checkpoint saved remotely at 004e93129402707adf4a358cb34c5ea5d55b0346. Fresh preflight: 36924021211. Manual signing-only build: 36924238214 (publish_to_apple=false). The redundant unsigned push run 36924021370 was requested to cancel. Results are pending; no Apple upload is claimed.
