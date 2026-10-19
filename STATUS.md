# Tayya 0.6.0 (13) — rescue checkpoint, 2026-10-19 UTC

Release is blocked. No accepted IPA, PR merge or Apple upload. Bundle ID: `com.ahmadalawi.hashiya`. Preserve Paper Studio, existing data formats and full Office support.

## Current evidence and decision

Product baseline remains `c8903523e8831b24d78e87923ea966408dd5419d`; the work branch has not adopted a production gesture repair.

[Tracking capture39187892547](https://github.com/x6one/hashiya-ios/actions/runs/39187892547), source `4a09c6adce73e648a885b6a4b5ab8064c4be229f`, meets its diagnostic goal: Tools14/14 pass; original phone Accessibility passes233.314s, then fails968 (original966) in130.702s and stops. Different app processes are involved.

- Failed input: size button starts native tracking at927.370031; pan loses its touch at927.385661 without scrolling. Scroll/pan stay enabled, offset remains−62.
- Passing input: pan begins and moves the same rail−62→−12; button tracking is not observed during that drag.
- The actual HostingScrollView inherits UIScrollView's cancellation implementation. The UIKit default refuses cancellation for UIControls. This strongly supports a delayed-touch handoff race; the old source's exact cancellation callback has not been captured.
- Full critical path,65 live observations and sampled transitions have zero omissions. Main-thread snapshots≈1.35ms. Full artifact SHA/ZIP CRC verified locally, original33KB attachment read without stdout truncation, and actual failure video reviewed. [Exact evidence](Verification/Diagnostics/rail-tracking-39187892547.json).

The previous `pan.delaysTouchesBegan=true` trial [39186654628](https://github.com/x6one/hashiya-ios/actions/runs/39186654628) is rejected: its first original Accessibility attempt fails brush selection before the rail drag; the recorded menu stays open. [Revert ca6272d](https://github.com/x6one/hashiya-ios/commit/ca6272dad17b77deaaee853407db620458db03a5) restores the production file, without another native run. It was never adopted by work. [Trial report](Verification/Diagnostics/rail-delivery-39186654628.json).

## Isolated repair under qualification

Source [756ddd7](https://github.com/x6one/hashiya-ios/commit/756ddd773c9881319adbf22eba664e64650b4b6d), branch `diag/tayya-rail-cancellation`, [run39189664681](https://github.com/x6one/hashiya-ios/actions/runs/39189664681): **not accepted; native results pending**. Stage A14 Tools/syntax/actionlint/capture checks pass.

Only InkToolbar's scroll holder changes to an owned public UIKit subclass allowing cancellation of a tracking UIControl. Its exact HStack, Menu/button actions, native picker sheet and styling remain identical. The controller forwards the environment and owns/cleans up one child hosting controller. Navigation boundary, normal began-touch delivery, PencilKit and storage are unchanged.

Phone gate: original Accessibility until first failure/max3, then require an actual callback showing inherited0→cancel1 on an already-tracking control; then original Standard ink/navigation. iPad's three original cases run only after phone success; a wide rail fitting all targets need not scroll. Compare actual effective safe-area viewport, height/content width and control reachability on both families. Match callback identities to the tested rail before acceptance.

Next issue only: qualify this cancellation policy. No full C or packaging until targeted B succeeds.

## Release gates

All gates must refer to the same final IPA source:68 XCTest including all67 originals,32 original XCUITest and3 Maestro flows per family; actual exported-byte checks; real screenshot review; full native Office device build; version/build/bundle/resources; IPA integrity and independently verified SHA256. An unsigned IPA needs valid signing.

The font resource fix and Files setup cleanup remain isolated candidates; partial native passes are not stability qualification. Prepared sequential release pipeline `0740022a74cd4a485cb34d8b265a14060ccadb0c` on `prep/tayya-release-gates` remains unadopted and natively unqualified. Internal PR duplicates are skipped only for branches already covered by push.

Local execution has recovered. Python/ffmpeg now inspect saved bytes locally; Linux has no Swift/Xcode. Native verification still requires Actions. Earlier transport failures are historical, not a current excuse to spend CI on evidence reading.

## Evidence history

[Previous checkpoint preserved verbatim](docs/history/STATUS-before-rail-cancellation-2026-10-19.md) links all prior captures, font/harness experiments and baseline failures. [Original status archive](docs/history/STATUS-before-rescue-2026-10-19.md) and [original verification archive](Verification/Diagnostics/0.6.0-13-before-rescue-2026-10-19.json) are unchanged.
