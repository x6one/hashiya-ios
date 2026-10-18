# Tayya 0.6.0 (13) — rescue checkpoint, 2026-10-19

Release is blocked. No accepted IPA, PR merge or Apple upload. Bundle ID: `com.ahmadalawi.hashiya`. Retain Paper Studio, existing data formats and Office conversion.

## Candidate and next decision

- Development audit: `6be37f9550d39355ab4a8291e7c0e162c85d9a1b`; product baseline remains `c8903523e8831b24d78e87923ea966408dd5419d`.
- Font candidate: `c2f69c0146dcbacaced8fdf27f37cdd5adf30e94`, separate `diag/tayya-rescue-font` branch. Only generated demonstration PDF fonts change to public ArialMT/Arial-BoldMT names. Existing documents are not rewritten.
- Targeted qualification [39170507839](https://github.com/x6one/hashiya-ios/actions/runs/39170507839): all68 unit tests (67 originals plus font regression), then the unchanged two original ink cases and navigation case on each family. Pending. Do not adopt a partial pass or start full preflight until this is reviewed.
- Next decision: inspect actual exported font dictionaries, native ink/Redo and navigation outcomes, then accept or reject this one candidate. Do not add a navigation workaround without failure evidence.

## Evidence

| Issue | Verified evidence | Unresolved |
| --- | --- | --- |
| Redo waiter | c890 Push iPad: native PencilKit sees2 strokes18:07:51.035UTC; AX query51.213 finishes58.522 (7.31s), exceeding5s; later native count2 matches expected2 | Why the snapshot is slow; do not call this drawing loss |
| Generated PDF fonts | Run39169663987:2 existing guide tests pass; added font test fails63. Actual BaseFont names are privateSF names matching CoreText fallback warnings. Artifact12151789151 SHA25618a878ad5a5b5ee2aa30d89bf9c259e810da8fc71d41fcb515e53c7bf94c9480 | Whether public document fonts remove the latency and UI failures |
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
