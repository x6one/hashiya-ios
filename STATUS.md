# Tayya 0.6.0 (13) — rescue checkpoint, 2026-10-19 UTC

Release is blocked. No accepted IPA, PR merge or Apple upload. Bundle ID: `com.ahmadalawi.hashiya`. Retain Paper Studio, user data and Office conversion.

## Current decision

- Product baseline remains `c8903523e8831b24d78e87923ea966408dd5419d`; no production gesture repair is adopted.
- Fixture candidate `c7d1071568340990e6ad2fa01e99e579884ac32b` on `diag/tayya-fixture-cleanup` releases DocumentsApp after setup resolves the provider container. It does not rewrite exports or bypass native Save/import.
- Stage A: added setup contract fails on the old helper ([39176410569](https://github.com/x6one/hashiya-ios/actions/runs/39176410569),13 originals pass,1 new failure); after cleanup,14/14 Tools tests pass ([39176525816](https://github.com/x6one/hashiya-ios/actions/runs/39176525816)). The foreground leak is proven; its causation of the native launch failure is still a hypothesis.
- Stage B [39176525816](https://github.com/x6one/hashiya-ios/actions/runs/39176525816) failed: navigation3/3, native PDF/PowerPoint imports2/2 and actual exported bytes pass **each** family; Standard ink passes each, Accessibility ink fails each. iPhone1151: native strokes1→2 but red-pixel delta0. iPad1096: dismissal waiter fails after the remote picker scene has been invalidated. This candidate is not accepted as a stability repair.
- Picker query [39178692188](https://github.com/x6one/hashiya-ios/actions/runs/39178692188), source `d3db4b063fa4664f0580f5d2d5f621deb37c890d`, is **not accepted**: iPad2/2 original ink cases pass; iPhone Standard passes, Accessibility fails966 at Fit Width because the rail target remains x431.3333 after the measured drag. All8 reached picker-dismissal guards pass with the original5s budget. Stage A14 Tools/syntax/actionlint/read-only capture checks pass. No full suite/package ran.
- Next bounded diagnosis: `cdb7f8afc471dc5a7eb0a0d655744a1b0adc073d` on `diag/tayya-rail-input`, iPhone Accessibility until first failure/max3 then Standard once. The earlier observer retained dead weak-reference keys; this could miss new recognizers at reused addresses, but occurrence in the failure is unproven. DEBUG-only live-identity observation, passive existing hit-path targets, omission counts and monotonic drag times improve evidence. Release code projection and every original assertion line remain identical. Independent source review found no blocker; native compilation/results pending. No gesture policy changes.
- Full failure details and artifact hashes: [ink-pair evidence](Verification/Diagnostics/ink-pair-39176525816.json). A native scene closing does not by itself prove its outer host vanished. The failed native drawing needs separate raster inspection; capture now copies actual temporary review drawing bytes after UI tests.
- Input control [39174774309](https://github.com/x6one/hashiya-ios/actions/runs/39174774309):85% deliberate edge input passes3/3 on iPhone; iPad passes2/3, with iteration1 failing at `app.launch()`1396 before any document interaction (XCTest background assertion). The related original ink case passes each family. All five reached edge assertions pass. This is not a production navigation repair or a qualified run.
- Public demonstration PDF fonts remove the private SF resource names (68/68 units per family including all67 originals); that candidate alone did not fix UI failures. Existing documents are not rewritten.

## Evidence

| Issue | Verified evidence | Unresolved |
| --- | --- | --- |
| Redo waiter | c890 Push iPad: native PencilKit sees2 strokes18:07:51.035UTC; AX query51.213 finishes58.522 (7.31s), exceeding5s; later native count2 matches expected2 | Why the snapshot is slow; do not call this drawing loss |
| Generated PDF fonts | Run39169663987:2 existing guide tests pass; added font test fails63. Actual BaseFont names are privateSF names matching CoreText fallback warnings. Artifact12151789151 SHA25618a878ad5a5b5ee2aa30d89bf9c259e810da8fc71d41fcb515e53c7bf94c9480 | Public fonts alone do not fix UI failures (39170507839); contribution to snapshot latency remains unproven |
| Current compact ink | c7 iPhone Accessibility1151: count1→2, visible red0→0; actual screenshot reviewed. Identical final viewport/zoom/ink bounds also occur in earlier passing39174774309 | Neither44pt height nor internal tiled-view hidden flag is a sufficient cause; preserve/raster actual drawing before any renderer repair |
| Current picker dismissal | c7 iPad: scene invalidates23:42:45.381UTC, scene record clears45.394, first AX absence query starts45.910; later serial negative lookup retries precede failure23:43:05.736 | Candidate batches both absence conditions without changing assertion or5s budget; outer-host absence still needs evidence |
| Native color picker | c890 PR-phone actual video: white outer sheet/Done. Service requested17:59:45.876UTC, bootstrap18:00:03.111, ready05.800 after5s waiter | Underlying remote-service launch delay; do not redesign presenter from this evidence alone |
| Edge Back | Probe39168607576: iPhone fails1424, iPad passes55.053s. Both show enabled right-edge8, RTL1, stack2, content disabled. Observer-only39169870462 phone passes66.804s; edge begins/ends and stack becomes1 | Intermittent failure cause; observation success is not a repair |
| Other baseline failures | Push phone: zero Fit Width rail movement, palette dismissal, paged-margin/light-journey caps. PR iPad: PowerPoint Files export callback184 | Must pass the full unchanged suite on final source |

Both original baseline runs39151098686/39151102579 pass67 unit tests and exported-byte checks in all4 jobs. Maestro/package skipped. Full baseline details: [c890 evidence](Verification/Diagnostics/c890-rescue-evidence.json). Partial native log collection timed out; absence of crash reports does not prove no crash.

## Release gates

All gates must refer to the IPA source SHA:68 XCTest (including all67 originals),32 XCUITest and3 Maestro flows per family; externally exported bytes; actual screenshot review; full native Office device build; version/build/bundle/resources; ZIP integrity and independently verified IPA SHA256. No unsigned package is directly installable.

PR matrix duplication is skipped only for internal main/work/** branches covered by push; forks and other internal branches retain PR verification. A prepared reusable Office job replaces the lightweight non-Office IPA and runs only after both complete test jobs succeed. This pipeline change remains isolated on `prep/tayya-release-gates` at `0740022a74cd4a485cb34d8b265a14060ccadb0c`, not adopted by the work branch or natively qualified. It stages Tools→three regression cases→fresh same-runtime/device-type simulator→complete suites→Maestro/exports→full Office. Both raw result bundles are attempted even when summary/export fails; failure is retained. Reusable calls expose no signing/upload inputs or secrets; signing steps additionally require a direct dispatch of the Office workflow.

Local baseline Tools13/13 pass. Current isolated diagnostic Tools14/14 pass. Earlier prepared pipeline V2 passes actionlint1.7.7; the current V3 fresh-simulator addition remains unqualified. V2 (shellcheck/pyflakes integrations disabled); [39177156534](https://github.com/x6one/hashiya-ios/actions/runs/39177156534) also exercises summary/export failure and confirms both raw bundles are still attempted with nonzero exit. Linux has no Swift/Xcode; native verification uses Actions. Do not treat local checks as native acceptance.

## History

Earlier detailed notes are preserved byte-for-byte in [the status archive](docs/history/STATUS-before-rescue-2026-10-19.md) and [the prior verification archive](Verification/Diagnostics/0.6.0-13-before-rescue-2026-10-19.json). Read the current decision above before opening historical experiments.

Local execution interrupted during preparation: `exec-server transport disconnected; recovery timed out`. GitHub source reads/writes remain available. Latest diagnostic Stage A runs on Linux Actions and passes its own syntax/lint/Tools checks; this does not qualify native behavior.
