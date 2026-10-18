# Tayya 0.6.0 (13) — rescue checkpoint, 2026-10-19

Release is blocked. No accepted IPA, PR merge or Apple upload. Bundle ID: `com.ahmadalawi.hashiya`. Retain Paper Studio, user data and Office conversion.

## Current decision

- Product baseline remains `c8903523e8831b24d78e87923ea966408dd5419d`; no production gesture repair is adopted.
- Fixture candidate `c7d1071568340990e6ad2fa01e99e579884ac32b` on `diag/tayya-fixture-cleanup` releases DocumentsApp after setup resolves the provider container. It does not rewrite exports or bypass native Save/import.
- Stage A: added setup contract fails on the old helper ([39176410569](https://github.com/x6one/hashiya-ios/actions/runs/39176410569),13 originals pass,1 new failure); after cleanup,14/14 Tools tests pass ([39176525816](https://github.com/x6one/hashiya-ios/actions/runs/39176525816)). The foreground leak is proven; its causation of the native launch failure is still a hypothesis.
- Stage B [39176525816](https://github.com/x6one/hashiya-ios/actions/runs/39176525816):3 navigation repetitions, both original ink cases, both actual PDF/PowerPoint picker imports and exported-byte verification per family. Pending. Full preflight and IPA remain blocked.
- Input control [39174774309](https://github.com/x6one/hashiya-ios/actions/runs/39174774309):85% deliberate edge input passes3/3 on iPhone; iPad passes2/3, with iteration1 failing at `app.launch()`1396 before any document interaction (XCTest background assertion). The related original ink case passes each family. All five reached edge assertions pass. This is not a production navigation repair or a qualified run.
- Public demonstration PDF fonts remove the private SF resource names (68/68 units per family including all67 originals); that candidate alone did not fix UI failures. Existing documents are not rewritten.

## Evidence

| Issue | Verified evidence | Unresolved |
| --- | --- | --- |
| Redo waiter | c890 Push iPad: native PencilKit sees2 strokes18:07:51.035UTC; AX query51.213 finishes58.522 (7.31s), exceeding5s; later native count2 matches expected2 | Why the snapshot is slow; do not call this drawing loss |
| Generated PDF fonts | Run39169663987:2 existing guide tests pass; added font test fails63. Actual BaseFont names are privateSF names matching CoreText fallback warnings. Artifact12151789151 SHA25618a878ad5a5b5ee2aa30d89bf9c259e810da8fc71d41fcb515e53c7bf94c9480 | Public fonts alone do not fix UI failures (39170507839); contribution to snapshot latency remains unproven |
| Native color picker | c890 PR-phone actual video: white outer sheet/Done. Service requested17:59:45.876UTC, bootstrap18:00:03.111, ready05.800 after5s waiter | Underlying remote-service launch delay; do not redesign presenter from this evidence alone |
| Edge Back | Probe39168607576: iPhone fails1424, iPad passes55.053s. Both show enabled right-edge8, RTL1, stack2, content disabled. Observer-only39169870462 phone passes66.804s; edge begins/ends and stack becomes1 | Intermittent failure cause; observation success is not a repair |
| Other baseline failures | Push phone: zero Fit Width rail movement, palette dismissal, paged-margin/light-journey caps. PR iPad: PowerPoint Files export callback184 | Must pass the full unchanged suite on final source |

Both original baseline runs39151098686/39151102579 pass67 unit tests and exported-byte checks in all4 jobs. Maestro/package skipped. Full baseline details: [c890 evidence](Verification/Diagnostics/c890-rescue-evidence.json). Partial native log collection timed out; absence of crash reports does not prove no crash.

## Release gates

All gates must refer to the IPA source SHA:68 XCTest (including all67 originals),32 XCUITest and3 Maestro flows per family; externally exported bytes; actual screenshot review; full native Office device build; version/build/bundle/resources; ZIP integrity and independently verified IPA SHA256. No unsigned package is directly installable.

PR matrix duplication is skipped only for internal main/work/** branches covered by push; forks and other internal branches retain PR verification. A prepared reusable Office job replaces the lightweight non-Office IPA and runs only after both complete test jobs succeed. This pipeline change is not yet published or natively qualified. Reusable calls expose no signing/upload inputs or secrets; signing steps additionally require a direct dispatch of the Office workflow.

Local baseline Tools13/13 pass. Prepared release workflows pass actionlint1.7.7 (shellcheck/pyflakes unavailable) and whitespace checks. Linux has no Swift/Xcode; native verification uses Actions. Do not treat local checks as native acceptance.

## History

Earlier detailed notes are preserved byte-for-byte in [the status archive](docs/history/STATUS-before-rescue-2026-10-19.md) and [the prior verification archive](Verification/Diagnostics/0.6.0-13-before-rescue-2026-10-19.json). Read the current decision above before opening historical experiments.

Local execution interrupted during preparation: `exec-server transport disconnected; recovery timed out`. GitHub source reads/writes remain available. The latest diagnostic edits received exact-replacement/whitespace/manual configuration review, but local actionlint could not run on them. Earlier prepared-release lint results do not qualify these later edits.
