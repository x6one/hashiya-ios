# Tayya 0.4.1 (9) — paged margins and handwriting repair

Final tested and uploaded source: `e3e0f4da30656265ef9c1d617a9af0ba85c9b73c`. PR #3 merged on October 8 as `90dff347b0c460faafd77a31605e7502a7ffb40f`. This report was finalized on October 8 after checking App Store Connect.

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

Final push preflight `37689943878` and PR preflight `37689950884` succeeded. Each device family passed 34 unit tests and 11 UI tests (90 tests across iPhone and iPad), plus unsigned device packaging. Five existing release-tool regression tests passed locally. Explicit native/sign/upload run `37690165583` succeeded for the same source, and App Store Connect processed build 0.4.1 (9).

The demonstration tests verify complete PDF guide content, two populated editable margin pages, persisted installation, preservation of user documents and edited demonstration content, and rollback after failed publication. The UI flow opens the Release-visible demonstration card and navigates its populated margin pages. PDF guide layout verifies that every glyph fits; extraction checks use an ASCII end marker to avoid Arabic text-order assumptions.

## Apple scope
The user subsequently authorized rejection investigation and delivery. Apple rejected 0.3.0 (7) on October 6 under 2.1(a), requesting pre-populated demonstration content; the review device was iPad Air 11-inch (M3). A real local demonstration mode is now available from the library card, installing a three-page PDF guide, a three-page writing notebook and a PowerPoint sample, each with two populated margin pages. No login is needed. App Store and beta review notes explain the exact Arabic controls and import/create/edit/export flows.

On October 8, the standard third-party encryption questionnaire was completed truthfully; France remains excluded. The build UUID is `9eb1e731-d398-485e-a3a3-50cff8cc3efe`. Build 9 was added to Tayya Beta and Tayya Internal with automatic tester notification selected. External TestFlight status was verified **Waiting for Review**. The public link remains https://testflight.apple.com/join/bBwnghMX .

App Store version 0.4.1 has build 9 attached, revised Arabic metadata and five screenshots for each large iPhone/iPad device class. The prior submission `c0340bad-b3a1-483f-9b49-d20aa46ebcac` was resubmitted on October 8 at 3:05 PM Qatar time; both its submission and version row were verified **Waiting for Review**. Automatic release after approval remains selected. Price is free and the existing Data Not Collected declaration remains. Neither Apple approval nor public availability of build 9 is claimed.
