# Tayya 0.6.2 precision ink — release handoff

Owner approved implementing this update and conditional signing, upload, App Review and automatic release. No stable/main application merge is authorized. Work stays on `integration/tayya-precision-ink`; base `d45457bdd216265b11d58ba844fcda22fb6297d9`. Version0.6.2, build17, bundle `com.ahmadalawi.hashiya`, app6818288428. Existing public0.6.1(16) is preserved.

## Implemented, not yet release-qualified

- Shared production PencilKit stroke editing: straighten selected strokes in place, recolor, width, endpoint controls, direct line and uniform highlighter, native ruler on PDF and Notes.
- Original independent canvas history, atomic Notes save/deferred UI publication, file names, data formats and audio anchors retained. No dependencies added.
- Existing163 native test methods retained; current inventory133 unit +58 UI =191/device. No removed original assertions or widened timeouts.
- AR/EN What's New in `Store/metadata.json`; original published name/subtitle/privacy URL retained.

## Evidence and current input regression

- Geometry assertion RED: [43203556205](https://github.com/x6one/hashiya-ios/actions/runs/43203556205). Controller RED then seven GREEN on iPad: [43208345826](https://github.com/x6one/hashiya-ios/actions/runs/43208345826).
- Five reviewer regressions had nine failed assertions on actual native execution [43214460285](https://github.com/x6one/hashiya-ios/actions/runs/43214460285). Fixes cover pre-consumption Undo guard during active drawing, stale pending tool policy, zoomed Notes handles, deselection cleanup and nearest endpoint.
- [43233260192](https://github.com/x6one/hashiya-ios/actions/runs/43233260192), source94816d8:49/49 native tests/device and Notes UI pass. PDF first ruler drag hit the ruler body: original video confirms moving the ruler, no stroke expected from that interaction. Corrected test draws on clear paper with unchanged exact count/history/page assertions.
- [43237049481](https://github.com/x6one/hashiya-ios/actions/runs/43237049481), sourcee885462: corrected PDF test passes iPad; iPhone native ruler+Undo pass, then midpoint selection fails.
- Original Notes screenshot and saved PKDrawing reveal a separate real input defect: intended startx130 on the650-point page was stored as398.827, end487.901 matched intended487.5. This is truncated saved geometry, not a display-only GPU claim. Saved-data regression was replayed and failed before the fix; the new UI pixel-corridor regression was not separately executed RED.
- Source5e0dfffb uses `InkPanGestureRecognizer` to retain first UITouch contact before UIPan translation rebasing. New real Notes pixel-corridor assertion and original PDF midpoint assertion are mandatory. Paired verification passed28/28/device, zero failures/skips: [43241234689](https://github.com/x6one/hashiya-ios/actions/runs/43241234689). Both Notes whole-line pixel corridor and PDF midpoint selection passed. Original before-history and PDF PNGs were visually inspected on both families. Retained iPad artifact13955946993 and iPhone13956476803 keep raw screenshots and xcresult. This targeted success is not the full release gate.

## Remaining release gates, in order

1. Read the paired first-contact result; diagnose its first actual failure before edits or another run. Review original new-feature screenshots.
2. Freeze one candidate and push `[integration:release] [store:captures]`. Full production gate requires every native case, original cold regressions, Maestro3/device, actual PDF/PPTX export bytes, genuine production gallery and full native Office/iphoneos package. Store captures separately use the required actual medium iPhone dimensions; they are not substitutes for release tests.
3. After all seven required preflight jobs pass on that exact SHA, use source-pinned `office-engine-spike.yml` dispatch to sign the real application; preserve XCArchive, IPA, signing/resource validation, SHA256 and actual Apple upload/processing receipt. Recheck build17 remains unused immediately before upload. Never rebuild or reupload an accepted build.
4. Attach the accepted build to the existing app/version, apply validated12 store images and AR/EN metadata, submit using official App Review endpoints and automatic release, only if the credential has the needed role. No public-release claim without Apple state confirmation.

## Retained original design and Office inputs

- Approved Studio sourcee94c2cbb original gallery expired.37 byte-exact before PNGs were recovered from production-review artifact13037308637/run41181915781, SHA256 `4a821d675259fd89cac2988963c5c9bf6110631245e2f8769539450a090e37a1`. The recovery validates source/hash/metadata and keeps missing comparison contexts explicit; no pixel modification or old Studio rerun.
- Office source inputs unchanged. Pinned existing arm64 engine artifact13080813474/run41181915781,265995124bytes, SHA256 `42f462205aed991a63e1cab4e128906191d8f81482ac09c0c32c77fddf87eef1`, expires2026-11-15. Reuse retains linkage and current app/package checks; original build fallback remains.

## Proven external blocker

[43213543513](https://github.com/x6one/hashiya-ios/actions/runs/43213543513) returned Apple403 `FORBIDDEN_ERROR` on `POST /v1/appStoreVersions` for0.6.2: **The API key in use does not allow this request**. No new draft, binary upload or review submission was made by that job. No authenticated Apple browser session or official key/secret management tool is available here. Same rejected request must not be retried unchanged. App Manager is sufficient; a broad Admin role is not requested. If access remains unchanged after engineering gates, owner must replace the existing ASC GitHub secrets with an App Manager API key through the secret UI, never through chat/source/logs.

Simulator capture/automated tests do not establish physical microphone quality, Apple Pencil feel or Office conversion fidelity on an actual device. State these limits without claiming manual device testing occurred.
