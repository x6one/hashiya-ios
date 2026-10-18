# Tayya 0.6.0 (13) — rescue checkpoint, 2026-10-19

Release is blocked. No accepted IPA, PR merge or Apple upload. Bundle ID: `com.ahmadalawi.hashiya`. Retain Paper Studio, existing data formats and Office conversion.

## Current decision

- Development audit: `6be37f9550d39355ab4a8291e7c0e162c85d9a1b`; product baseline remains `c8903523e8831b24d78e87923ea966408dd5419d`.
- Font candidate: `c2f69c0146dcbacaced8fdf27f37cdd5adf30e94`, separate `diag/tayya-rescue-font` branch. Only generated demonstration PDF fonts change to public ArialMT/Arial-BoldMT names. Existing documents are not rewritten.
- Targeted qualification [39170507839](https://github.com/x6one/hashiya-ios/actions/runs/39170507839): 68/68 XCTest pass per family. UI: iPhone1/3 (Accessibility rail966 and native edge1424 fail); iPad2/3 (standard ink native picker1049 fails). Original test assertions and case deadlines are unchanged.
- **Candidate rejected as a stability repair.** The new PDF uses only ArialMT/Arial-BoldMT resources, but the same UI faults persist. Do not promote this candidate or start full preflight.
- Follow-up evidence [39171913705](https://github.com/x6one/hashiya-ios/actions/runs/39171913705): iPhone0/2 original cases, same rail966 and edge1424 failures; iPad1/1 standard ink passes. Instrumented success is not a repair. Edge began24.584 and ended25.118 (22:35UTC, stack1); no content-pop restore occurred during the failed edge. The early-restore hypothesis does not explain this occurrence. No observed rail scroll pan began during its failed drag.
- Transition/hit evidence [39173378390](https://github.com/x6one/hashiya-ios/actions/runs/39173378390): iPhone rail passes; native edge still fails. UIKit cancels at61.7424% with440pt bounds and ending velocity−240pt/s, then completion restores stack2. No boundary restore intervenes. The underlying cancellation decision remains unproven. Rail hit point exactly matches the test; size/inset/offset support a50pt scroll, which occurs in this observation. No deterministic Menu/extent defect established.
- Next input candidate: `f47b77b9da7a26bb023574da83b45d4f4cc8fceb`, [39174774309](https://github.com/x6one/hashiya-ios/actions/runs/39174774309). Change only the nav test drag65%→85%, retaining every original assertion and waiter; repeat3 times per family, then capture that family's original failing ink case. This tests clearer completion intent; it is not a production navigation repair. If85% cancels, investigate the existing content-pop policy with controlled comparisons rather than extending the drag again.


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
