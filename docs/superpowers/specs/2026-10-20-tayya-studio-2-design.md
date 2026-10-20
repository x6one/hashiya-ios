# Tayya Studio 2.0 — visual proposal (approval pending)

## Authority and boundary

The user's attached board and numbered brief authorize phases A/B now: audit,
design system, isolated working SwiftUI previews and an implementation plan.
The user explicitly places the approval gate AFTER seeing those previews.
That instruction takes precedence over additional skill approval handoffs.
Production interface replacement, data migrations and phase C are NOT approved.

Stable rollback source: `dbdb264bf86a6606be095aad22cd303ad01e2071` on
`work/tayya-calm-workspace`. Run [39342393075](https://github.com/x6one/hashiya-ios/actions/runs/39342393075)
passed 68 unit/32 UI/3 Maestro on EACH family and native Office device packaging.
Its unsigned IPA SHA256 is `a6f44f6c4298c0e3136b444b76bc2fcdb3df3fe1fa26dc46d16a35fa0544db73`.
Physical-device Office conversion remains unverified. STATUS.md at that frozen
commit predates the finished run; the completed run/artifact establish the result.

Worktree: `/workspace/tayya-studio-2`; branch: `design/tayya-studio-2`.
The preview has a separate XcodeGen project and bundle identifier
`com.ahmadalawi.hashiya.studio.preview`, no shared container/production sources,
no disk writes, microphone, network, signing, or Office integration. The production
bundle remains `com.ahmadalawi.hashiya`; iOS minimum remains 17.

## A — findings from current source

| Area | Existing behavior | Design response / later integration |
|---|---|---|
| LibraryScreen | Continue card, covers, filters, four destinations already exist. Trash is exposed in library, sidebar and Settings. | Keep four destinations; compact brand/search/add header; move occasional file management into one menu/Settings; retain restore/backup. |
| PDFWorkspace | Tool-group selector, action row, page row, recording row and ink toolbar compete vertically. | Phone: title/actions + page navigator, content, contextual pen rail and five-tool dock. Sheets own rare actions. |
| iPad | Existing draggable split preserves ink; global `tayya.splitFraction`; no persistent thumbnail sidebar. | Dedicated 3-column study layout: thumbnail sidebar/document/margin. Hide sidebar, drag split, focus control. Later scope split preference by notebook with old global fallback. |
| Reading | LibraryReadingPosition already saves per notebook. | Reuse storage; never re-fit on pen changes. Preserve selected page/destination through presentation changes. |
| AudioLinks | Existing clip/time/page/textID/strokeCount/label links in links.json; marker tap already jumps then seeks. | Preserve schema and paths. Show recording/markers in a page audio card. Add optional metadata, never rename M4A files just to rename a title. |
| RecordingStrip/PageAudio | Independent strip and metering object already isolate timer ticks. Permission/interrupt/background handling and legacy peer playback exist. | Preserve isolation. New playback speed, manual markers and rename presentation require tested APIs later. |
| Page editing | Page removal/remapping/legacy recordings already have dedicated tests. | Test move/delete against linked and legacy audio; preserve detached/orphaned clips visibly rather than silently losing them. |
| Existing visual tests | 32 UI cases include actual screenshot exports, light/dark/large type, ink pixel/geometry tests. | Keep them; add targeted preview geometry/interaction coverage. No SnapshotTesting package needed in A/B. |

## B — direction

Use the reference's quiet paper, deep green, copper accents, book covers and
separate study surfaces. Typeset correct Arabic, use real SF Symbols and generate
an actual PDF for previewing; do not reproduce the board's distorted text or icons.
Use native system Arabic/English typography rather than add a font dependency.

### Semantic tokens

| Token | Light | Dark | Use |
|---|---|---|---|
| background | #F8F7F3 | #151E1B | App chrome |
| surface | #FFFFFF | #202C27 | Cards/panels |
| primary | #244C43 | #B9D8C9 | Actions/icons; dark text on dark primary fill |
| copper | #C48F68 | #D5A583 | Decorative emphasis; never small body text on white |
| selection | #E9EFEA | #314A3E | Selected controls |
| text | #282C2B | #F1F3EE | Main text |
| secondary | #5E6963 | #B0BDB5 | Supporting labels |
| divider | #DEE3DE | #405147 | Boundaries |
| destructive | #A83432 | #FFB4AB | Stop/delete with icon and label |

Spacing 4/8/12/16/24; cards radius 16, sheets 24, controls 12.
Controls at least 44x44. Scale text with Dynamic Type. Horizontal tool rails
scroll at small widths; card grids collapse for accessibility sizes. Logical
leading/trailing supports RTL. Media skip directions and numeric times remain
unambiguous. PDF paper stays readable in dark mode; chrome adapts semantically.
Compute WCAG contrast for actual foreground/background token pairs in CI.

### Library

Brand + compact Add menu, search, continue-reading panel, horizontal section chips,
All/Favorites filter and consistent notebook grid. Four bottom destinations on
phone; corresponding sidebar on iPad. File management lives in Settings/menu.
No second always-visible New/Import row. Add menu owns both actions.

### Phone study

Back/title/bookmark/share; Previous/page/total/Next/thumbnails; PDF occupies the
remaining area. Bottom dock: Pen/Text/Select/Margin/Pages. Pen shows scrollable
ink/pencil/highlighter/eraser/color/width/Undo/Redo controls. Audio is an independent
compact strip; tapping its card opens recordings without opening margin. Margin
can expand and return to PDF. Sharing/templates/page operations open sheets.

### iPad study

Optional thumbnail sidebar; PDF in the center; independent margin panel; draggable
divider. Compact shared toolbar and independent bottom audio strip. Focus hides
secondary chrome and offers a visible exit. Portrait collapses thumbnails before
crowding writing panes. Previews include portrait and landscape.

### Page audio / flashcards

Audio card: document/page context, title/rename, elapsed/status/Stop and save,
playback +/-10 seconds, speed, manual marker. Marker list combines page changes,
writing and manual marks. Tap seeks and changes page. Recording continues through
page navigation. M4A retention/permission/interrupt/background/return are production
integration tests in C, not claims made by this in-memory demonstration.
Waveform in the preview is illustrative; no microphone or audio file is used.
Document review shows page/file filters, reveal and assessment without leaving
study. Favorite pens, focus, paper templates and quick navigation are demonstrated
with local state; persistence belongs to approved C tasks.

## Shared preview components

StudioTheme, TayyaPrimaryButton, TayyaIconButton, TayyaToolbar,
TayyaDocumentCard, TayyaAudioCard, TayyaPageNavigator, TayyaSectionHeader,
TayyaEmptyState. Production names/adapters are decided against existing
WorkspaceAction/InkToolbar/TayyaTheme at integration, avoiding duplicate systems.

## Tool/dependency decisions

Superpowers skills are already installed/readable; no npx reinstall.
No Penpot connection/tool is available. SwiftUI previews on existing free macOS
Actions runners are the explicitly requested fallback. XcodeGen/SwiftLint/
SwiftFormat are checked before installing on that runner. Scope format/lint to
DesignStudio files. Standard SwiftUI animation only, honor Reduce Motion.
No Lottie, SnapshotTesting, fonts or other product packages are added in A/B.
Existing real UI attachments plus added bounds/RTL/dark/type checks are sufficient
for proposal review; reconsider pixel baselines only after visual approval.

## Approval deliverable

Actual simulator PNGs for library, document, margin, page audio and flashcards in
light/dark on iPhone/iPad; dedicated tablet workspace portrait/landscape; English
and accessibility-size samples; state-interaction and capture results; action map;
file plan. Identify them as SwiftUI prototype captures, not redesigned production.
STOP for the user's visual approval before touching App/, Tests/, UITests/ or the
canonical project.yml. No stable branch writes, PR merge, Apple upload or IPA in B.
