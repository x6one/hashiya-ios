# Tayya Studio 2.0 — action map and handoff

All locations below are proposed. Production behavior is retained until approval.

| Screen / area | Control | Result | Preview / integration status |
|---|---|---|---|
| Library header | Add | New notebook / native import | Local notebook form works; native import is existing production integration |
| Library | Search / sections / favorite | Filter books; open notebook | Local sample state |
| Library | Continue reading | Open document at page7 | Sample; reuse existing per-document position in C |
| Library bottom / tablet sidebar | Library / Sections / Review / Settings | Four clear destinations | Local navigation |
| Settings | Trash / Backups | Restore/delete and backup/restore panels | Empty proposal states; preserve existing stores in C |
| Document header | Back / Bookmark / Share | Library / toggle / export panel | Back/toggle and share-text work; PDF/audio export adapter in C |
| Document navigator | Previous / page count / Next / grid | Change page / open thumbnail sheet | Local page state, actual PDFKit page updates |
| Phone dock | Pen / Text / Select / Margin / Pages | Contextual tools / text / native PDF selection / independent notes / thumbnails | Local/native views; existing tool integration in C |
| Pen rail | Ink / Pencil / Highlight / Eraser | Change native PencilKit tool | Works in preview canvas |
| Pen rail | Color / Width / Undo / Redo | Color sheet / cycle width / native canvas history | Works in preview canvas |
| Pen rail | Favorite pens | Choose three study presets | Sample presets; editable persistence is C |
| Tablet | Thumbnails / drag divider | Hide/show sidebar / change pane size | Local split; preserve production ink+reading position in C |
| Header | Focus / Show tools | Hide secondary chrome / restore | Local reversible state |
| Margin | Text / ink / templates | Edit note/draw/change ruled-grid-dot-blank background | Native text/PencilKit, local template choice |
| Audio strip | Record / Stop and save / card title | Demo session / stop / open audio | Explicit simulation, never opens margin |
| Audio card | Rename / Manual marker | Demo display title / current page/time mark | Local; metadata/file compatibility tested in C |
| Audio playback | Play/pause / +/-10 / speed / slider | Demo state at bounded position | Simulation; real PageAudio adapter in C |
| Audio markers | Tap | Page + playback timestamp | Local page+seek contract, then return to document |
| Review | Page/file scope / Reveal / assessment | Contextual study view | Sample question; real Flashcards filters/storage in C |

## Files expected to change AFTER approval

| Batch | Existing production files | Evidence before accepting |
|---|---|---|
| System/library | TayyaTheme, LibraryScreen, LibraryThumbnail, LibraryDestinations | RTL/dark/type captures; library lifecycle/backup/restore |
| Phone tools | PDFWorkspace, existing WorkspaceAction/InkToolbar adapters | Touch targets, pen stability, pixels and fresh-stroke Undo/Redo |
| iPad/margin | PDFWorkspace, MarginPane, MarginNotebook, MarginPages | Split/rotate/read-position/persisted stroke regressions |
| Smart audio | PageAudio, AudioLinks, RecordingStrip, PDFWorkspace, DocumentPageRemoval, LegacyPageRecordings | Permissions/interruption/old M4A bytes/page remapping/seek/rate/rename |
| Extras | WritingPaper, Flashcards, existing document/library stores | Preset round-trip, templates, filters, old data decode |

System colors and supported SF Symbols live in the proposal's StudioTheme. Copper
is decorative; normal text/actions must meet4.5:1. Measured key contrasts:
light text13.19, secondary5.71, primary button9.59; dark text12.95,
secondary7.44, primary button11.13. Do not use copper for small text on white.

No migration is performed in A/B. In C, add optional Codable metadata/defaults;
never destructively rewrite legacy folders/links. A page's removal must retain its
recording visibly even when an anchor cannot be reassigned. Stop on microphone
denial/interruption according to tested existing policy, preserving files.

**Approval gate:** review native captures and choose design revisions/approval.
No production implementation, stable merge, Apple upload or new IPA before that.
