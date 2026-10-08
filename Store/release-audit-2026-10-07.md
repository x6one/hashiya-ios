# Tayya 0.4.1 (9) — paged margins and handwriting repair

Candidate source: final head of PR #3; exact source is recorded by its CI runs and the distribution report.

## Behavior and data handling
- Margin pages store typed notes and PencilKit data in separate atomic page files, with a versioned index and stable page UUIDs. Legacy text and drawings migrate to page one; legacy resources remain unchanged.
- A failed page save retains in-memory edits and prevents navigation/addition until saving succeeds. Invalid existing indexes/pages are reported rather than silently replaced.
- The sheet coordinate system is independent of pane dimensions. Drawing extents remain reachable, and fit/pan controls expose the whole drawing. Editor tool/mode survives full-screen and split layout transitions. Initial width fit keeps handwriting legible in a short pane; whole-sheet fit remains explicit, centered, and does not alter drawing coordinates.
- PDF navigation is above drawing areas, with explicit pencil/marker/eraser/color/width/undo/redo controls replacing floating pickers. Split resizing works horizontally and vertically.
- New PDF writing sheets append to preserve existing page-indexed ink, text, OCR, cards and audio links. A byte-identical copy of the app-owned PDF is retained before the first addition; external Files originals are untouched.
- The complete margin folder and retained PDF are included in backup/restore and permanent notebook removal. New margin text/title search uses the same local search service. PDF margin export includes every glyph of long notes on continuation pages, separate from ink.
- Audio markers remain local and can be played from the linked-recordings screen. No new remote service, telemetry, login, payment, tracking, SDK, native engine or encryption changes.

## Validation
Seven new unit tests cover migration/relaunch, save failure/retry, corrupt indexes, resize invariance, out-of-sheet stroke extents, backup collision/selection, long PDF export and preserved source PDFs. One real UI flow draws ink, saves distinct text/ink pages, resizes the divider, rotates both simulator families, expands/collapses the margin, adds a PDF sheet, navigates independently and relaunches the app.

The five existing release-tool regression tests pass locally. At `2e5438d`, all 32 unit tests passed on each family; the new UI flow stopped on an incorrect Other-vs-ScrollView test query. The iPad app-owned picker row was partly clipped by its sheet. Both test interactions were corrected without skipping coverage. Final Swift/UI CI is pending; this record is not an Apple-upload confirmation.

## Apple scope
App Store rejection reported by the user on 2026-10-07 is deliberately outside this repair request. Current review details have not been fetched. Existing standard third-party OpenSSL classification, France exclusion and public beta group remain applicable; do not claim no encryption or Apple approval.
