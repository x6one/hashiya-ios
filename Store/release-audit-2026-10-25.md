# Tayya Studio 2.0 App Store preparation

## Current status — October27

BLOCKED; this status supersedes historical pending-candidate notes below. Full
qualification40402135051/source9fd1 failed the original iPad
`testIndividualInkTargetsAtAccessibilityTextSize` at CompactSplitInk: live red
pixels0, while two native strokes were saved in950 bytes and independently
rasterized3880 red pixels. Cold iPhone4/4 passed; iPad3/4 passed. The downstream
152-case/device, Maestro, exports, gallery, Office and iphoneos/IPA gates did not
execute. No current qualified IPA or Apple upload exists.

The real-app worker/MainActor comparison40446156528 passed2/2 original cases,
without changing the production default. This is an inconclusive experiment,
not a repair. Saved failure and healthy native archives were then read on macOS
without building, testing or launching a simulator:40450187444 and40451160063
both succeeded. The healthy original-worker case also has CoreAnimation
synchronization timeouts and keyboard focus-expiry warnings. Those warnings do
not distinguish failure. App shader compilation completed in173ms in the failed
case, so a multi-second compilation stall is not established for this stroke.

The exact evidence, checksums, event coverage and limits are recorded in
`Verification/Diagnostics/native-ink-saved-log-comparison.json`. The actual App
head remains93ec4f9a9b0ea9c665782fa20fe48ec0d4ac7ef7; newer App code is DEBUG-only
diagnostic instrumentation. Release defaults are unchanged. The original5s
live-pixel requirement is preserved. No test or log-reader process is pending.
Do not repeat the same full gate or change rendering/responder behavior based
only on these non-causal warnings. A causal trace or reproducible minimal
real-app case is needed before a new production repair and frozen qualification.

The12 genuine branded Store images remain available in artwork run40290027945,
artifact12636063053, with their originalDD009 capture provenance. Publication
remains disabled; source guards, existing signing, encryption facts, live0.4.2,
stable branches and user data are unchanged. Physical microphone/interruption
quality and actual-device Office conversion remain unverified.

The user explicitly authorized App Store upload on October25. Qualified application source c07e69eb49bea0588efb6c0f8d24c8b8e777c67c/run40175783379 passed151 native tests and3Maestro flows per family, real PDF/PPTX bytes, native gallery, full native Office linkage and Release iphoneos packaging. These results qualify that source, not later sources.

New store preparation runs on integration/tayya-app-store; the original integration/stable branches remain untouched. The only production resource change is the UserDefaults CA92.1 declaration, for the app's own pen presets, language, first-launch, library and reading preferences. Existing FileTimestamp/SystemBootTime reasons, no-tracking and no-collected-data declarations remain unchanged. A real-plist contract failed before this declaration and all35Tools tests passed after it. No storage format, behavior, version, bundle or engine changes.

The old signing-status.json predates a later recorded successful Apple upload; it is not reliable evidence that credentials are currently missing. A read-only CI probe checks configured credential presence and the real App Store app/version/build state without logging keys or JWTs, creating credentials or uploading a build. Local GitHub CLI uses a different connection and cannot list this repository's secrets (403); do not infer missing secrets from that permission denial.

Apple currently requires Dynamic Island medium phone imagery and13-inch iPad imagery. Capture the actual iPhone17Pro at1206x2622; don't relabel large-phone captures. Designed assets use genuine current production UI, own isolated sample documents, licensed fonts, accurate benefits, RGB PNGs and preserved source hashes. Do not claim Apple approval or physical microphone/Office conversion testing.

Before upload: finish current-source native qualification after the privacy resource change, refresh the review instructions for the actual five-tool Studio dock, retain prior standard-encryption classification and France exclusion, and verify the signed native archive and Apple processing. Contact details must come from the existing authorized App Store record; no invented email or phone.

Sources checked October25: https://developer.apple.com/help/app-review/guideline-reference/2-3-3-screenshots/ ; https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/ ; https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons .


## Current-source delta review

Reviewed application source3461ad5b1b2dec0d41b1f510463feeb90309485e, App tree8450ba5af2106395bbfd021999e9c6722d85c90b. The native engine, bridge, pinned ZIPFoundation dependency and project version/device/bundle settings are unchanged from qualified c07e69e. Production changes since that source are the app-owned UserDefaults manifest entry and adaptive primary page navigation: the existing ViewThatFits fallback now applies at standard text sizes, and the page-number field has an explicit44pt content-shape focus touch. The other two App deltas are DEBUG-only self-authored study fixture strings and bounded thumbnail task logs behind --test-production-content. They do not change normal Release data, page/ink ownership, recording behavior or storage. The original Light capture passed on both families in run40199323239 before comprehensive qualification; the full candidate gate remains pending. A targeted search of current App Swift sources found no URLSession/URLRequest client, network connection client, telemetry/advertising SDK or external URL endpoint. This is a source check, not a dynamic network guarantee; the unchanged Office engine may fetch document external resources as disclosed in the published privacy policy.

The integration uses local library/PDF/PencilKit files, original compatible Notes storage, M4A recordings and local JSON page/ink audio links, review cards and user-chosen backup/share destinations. Preferences now include actual UserDefaults/AppStorage callers in PenPresets, TayyaLocalization, LibraryScreen and PDFWorkspace. CA92.1 is justified by app-owned settings, not the engine's system language lookup. Existing selected-file/app-storage timestamps and elapsed-time reasons remain. No collected-data or tracking category is introduced by the redesigned client. Physical microphone capture quality/interruption and Office conversion on a physical device remain unverified; simulator-generated M4A and exported file-byte checks must not be presented as that evidence.

The October2/4 signed native privacy and standard-OpenSSL encryption reviews remain the baseline for the pinned unchanged engine. New device packaging retains nm undefined imports, linked libraries, executable hash and the exact app-root privacy manifest in native diagnostics for current-archive inspection. Do not falsely set ITSAppUsesNonExemptEncryption=false or manufacture encryption documentation. Preserve the existing standard third-party encryption questionnaire and France exclusion; processed-build declarations and availability must be checked again at Apple before submission.

Read-only Apple authentication succeeded in run40190287201: all six existing signing/API secrets are configured, app6818288428 is accessible,0.4.2 is READY_FOR_SALE and0.6.0(13) is absent. No new keys, contacts, pricing or territories are created. New version description/reviewer instructions in Store/metadata.json describe the real five-tool dock, Settings demonstration content and real audio flow. Historical rejection/release data remains historical; no upload or review submission has occurred in this phase.

## Screenshot-loading evidence

Run40191760276 passed all3 iPad capture cases and2/3 iPhone cases; testArabicDarkProductionScreens timed out on pagePreview-2 at line163. Saved native accessibility/video show pages2–4 still loading while1/5 rendered in the visible viewport. The bounded original-case diagnostic40193571752 passed unchanged assertions; all five native images completed within0.347s and every view completion was uncancelled. This healthy trace does not establish the previous failure's root cause or a functional fix. No speculative production patch or timeout change was applied. The complete three-scene Store capture now retains the same task receipts to inspect the actual multi-case context if it recurs. Do not label the old failure fixed without evidence.

## Publication boundary

Tools/publish_store_listing.mjs prepares only the authorized new0.6.0 draft and verified, native-source branded images. It preserves the published0.4.2 record, existing review contact data, pricing and territories; never submits review, attaches an unprocessed build, changes encryption answers or uploads a binary. The separate Store-content workflow requires successful immutable native qualification and artwork run IDs and matching App tree hashes. Signing and binary upload retain the original office-engine-spike.yml explicit workflow_dispatch publish_to_apple guard. A real local workflow_dispatch request returned403 Resource not accessible by integration; the connected repository-owner tools support commit/ref writes but expose no dispatch operation. If unchanged, one manual GitHub Run workflow action will be needed only after the concrete qualified candidate and images are ready.


## Actual native menu and medium-phone navigation regressions

Run40195182152 passed all3 medium-iPhone capture cases; iPad Dark and RealAudio passed but Light stopped before tapping a favorite pen. The saved original native receipt reports usePenPreset-0 at(30,954,224,38), fully inside1032x1376, exists=true and hittable=true after the5s readiness waiter expired; the unmodified image shows the visible correct native row. The capture-only interaction now verifies the row is inside the display, touches its center, requires a new existing native apply=0 trace event plus committed pen/width, requires actual menu dismissal and preserves page/stroke count. No production pen/shared helper change or deadline increase. The original iPad Light case passed in run40196741104,1/1,132.378s.

Reviewing the six actually rendered marketing proofs then revealed clipped normal-size navigation on the medium phone. Strengthening the existing Light capture with its original primary-navigation checks produced native RED run40197208191: pageNumber frame(371.333,121.667,48,34) inside402x874, right edge419.333 extends17.333pt past the window. The first assertion stopped on the native UITextField's34pt AX editing rectangle. The UI screenshot independently shows the clipped field and missing direction arrows. The root layout difference is the default-text horizontal ScrollView around primary page controls; unlike the existing AX5 fallback, a ScrollView claims to fit while hiding actions.

Source3461ad5 adapts that same existing unscrolled ViewThatFits layout for every text size, keeps the normal fallback page/count inline to retain PDF space, and gives the already44pt-framed input an explicit content-shape focus gesture. Original AX5 frame checks remain unchanged. Both native targets exposed a literal44pt input rectangle after the production gesture repair: medium phone(217.667,116,48,44), iPad(924,87,48,44). The temporary inferred-touch-area fallback was never executed on either device and was removed before freezing; the strict original native-frame44pt assertion is restored byte-for-byte, with all window bounds and actual next/previous touches. No font shrink, new dependency, user-data change, remapped identifier or speculative thumbnail patch. Native Light validation run40199323239 passed1/1 per family: iPhone141.725s and iPad201.707s,0 failures/skips; modified-file SwiftLint/SwiftFormat also passed. These focused results do not replace comprehensive qualification.

The Store publisher requires each of the seven actual release job gates and all three actual artwork jobs, not merely a green workflow which ran Tools only. Twelve Node contracts cover the filesystem/hash/PNG/run/failed-upload/qualification boundaries. One independent review caught a producer-contract mismatch: collection records expose canonical test_url, not a run field. The validator now verifies the actual repository/run/job URL already produced by the collector; no old screenshot metadata is relabeled. Actual full-artifact validation is still required before Apple writes.


## October26 Store continuation

The12 refined real-source artwork images are verified in run40214217251,
artifact12606922443. Outer ZIP SHA256
`7fa0729d0e9ec42d16c5931279b10b8ceccda093ef8321e8b99fe209cb42b810`;
editable inner ZIP SHA256
`454d3ec368c4d6ec6d38d440ecfa7e7eb2b9427cfb7a9178c1c5c6fd19d42a7e`.
Only iPad06Focus differs from the first12: it uses the preserved real DarkFocus
capture, avoiding overlap caused by the test's freely placed annotation.
Native capture source/run remain c5d1990/run40211390688; controller/render
identity4517cfe/run40214217251 is recorded separately. No screenshots are invented,
retouched or relabeled as a different device capture. All12 original/output
hashes, PNG dimensions/RGB and both ZIP CRCs pass; all12 images were reviewed.
Apple's current screenshot-specifications page was re-read on October26:
required medium Dynamic Island iPhone and13-inch iPad, accepted1206x2622 and
2064x2752, no alpha. See
https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/.

The c5d1990 full qualification run40211390622 is FAILED: cold iPhone2/3,
iPad3/3; the full151/device, Maestro and Office stages were correctly skipped.
The iPhone AX5 compact Notes Undo case failed its observer deadline. Preserved
native evidence shows a valid edge tap and the same native UndoManager2->1 in
6.817ms, with AX value1 emitted before the logged deadline and successful Redo
later; no App Undo/data-loss defect was demonstrated. The timing-only original
case run40213938608 passed1/1 without App/timeout changes. The exact internal
waiter stall remains unproven. Test-only source5123b96 checks the first post-tap
value for both Undo and Redo AND asserts the read completes within the original
5s budget. All actual edge/pixel/stroke/fit/page requirements remain. Its native
verification is pending; no later candidate is qualified from this evidence.

The user has authorized Apple publication. The original manual Office workflow
and all native/signing helpers remain unchanged. A separately guarded Store
controller is being prepared to reuse only the engine candidate from the exact
successful seven-job release run, with an exact clean application checkout and
24 COMPLETE draft images. Explicit publication config+trusted branch/event/tag
are mandatory. The original signer records controller GITHUB_SHA; a separate
receipt attests the actual built checkout and signed IPA hash. No event or SHA
is forged. No Apple write/upload/review submission has occurred; publication is
still disabled until critical native qualification and controller review pass.


### 2026-10-26 — verified controls and frozen152-case candidate

Candidate `9fd1e6acb01bec0aa0c5a6b7a25eeaf9e5443227`, App tree `c8db1ddd12d24f4ef3a15e91f187815d6c553ebd`, is frozen for full run40402135051. All application and unit/UI test code matches verified control source65ea71d exactly; the release workflow strengthens its minimum to152 cases (99unit+53UI), retaining every original case and adding the separate native-menu negative control. Cold4/device, all152/device,3Maestro/device, actual PDF/PPTX byte exports, native gallery, fullOffice andiphoneos unsigned package remain mandatory. Current full qualification is pending; this is not an IPA or Apple-upload success claim.

The previous7c78 full run passed151/151,3Maestro and exported3063-byte PDF/54684-byte PPTX on iPhone. iPad passed149/151 with two failures: the already-imported PDF card did not open after a valid physical touch (root cause unproven; all3 original import cases later passed inaf8 without a functional repair), and an overstrong test-only menu timing condition. No old ink failure recurred. Keep those failed results; do not claim an import defect was causally repaired.

Architecture review after three observer forms found our mistake: dd009's original contract required a five-second framework wait to succeed, never a separate remote AX call wall-time SLO. The afc elapsed<=5 assertion was an added requirement. The same public waitForNonExistence(timeout5) must returntrue, foreground and original Notes/action postconditions remain, and wall time is retained diagnostically. The separate negative control uses the SAME oracle, leaves the actual menu open, requiresfalse/visible row/foreground and unchanged actual PDF geometry, conditional divider and page. Notes remain mounted behind the opaque PDF by design; AX existence does not mean visibility or an action. Latest622 original video shows actual closure by approximately2.61s after the touch record; nativeTrue after7s alone was never treated as physical timing proof.

Native run40399169136/source65ea passed BOTH controls2/2,0failed/skipped/expected failures. Original Dark completed Notes opening/closing, actual thumbnails and Focus; absence calls returnedtrue in2.236/1.456s. The unselected open menu correctly returnedfalse after6.615s and remained visible with unchanged layout/page. The original Focus and negative-control PNGs were visually reviewed. Small original-evidence artifact12689461855 SHA256`0059fbbc6585eade9ad8057a31707076347351b0753e011a209133b39845782b`,2557132bytes, SHA+CRC verified; full xcresult artifact12689566671 remains separate.

An earlier cold native ink thumbnail took24.25s while Metal compiled shaders, so captures now require actual visible pagePreview values to be rendered within one shared30s async-content allowance BEFORE the unchanged5s pixel/orientation check. No scrolling or whole-document rendering is requested. An empty full-size sidebar still fails; an empty<44px retained sidebar sliver is only a readiness-scoping heuristic for hidden content. Original pixel/PNG/orientation checks still run and the actual Focus image was reviewed. This changes test readiness, not app rendering, fonts, data or engine behavior.

Reuse actual native Store capture/artwork run40290027945/sourceDD009/artifact12636063053. All12 original compositions passed source/run/hash/RGB/dimension/CRC checks and visual review. App/NativeOffice/project trees did not change; keep genuine DD source metadata. Outer SHA256`a9426765df10985ba6ed07575308a957f11fa4eeca236ab8e99dcf0f506e75ab`; inner ZIP`6669acb230552fcf8ec6badeb412c8fa7abd8bb408b4065fdd4cc7233cf9965f`.

Controller production/build/unit/UI sources match the frozen candidate exactly. Only allowlisted Store/publisher material differs. publish_binary remainsfalse; no Apple writes or upload occurred. All7 actual qualification jobs must succeed before enabling the reviewed controller. Actual Apple processing, export compliance/build attachment and review remain separately verified after upload. Existing standard third-party OpenSSL classification and excluded France territory remain unchanged. Physical microphone/interruption quality and Office conversion on an actual device remain outside CI proof.
