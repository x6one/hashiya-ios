# Tayya Studio 2.0 — review build

**Phase B only. Visual approval pending.** Native SwiftUI prototype, with a separate
bundle/container. `App/`, `Tests/`, `UITests/`, production `project.yml` and stable
branch are unchanged. No microphone, M4A file, production data storage or Office conversion is
used by this preview. Preview drafts use this separate bundle’s sandbox only. Recording/playback progress and waveform are a **simulation**;
the rendered PDF and editable PencilKit/TextEditor surfaces are real native views.

## Review

The Actions workflow `Tayya Studio design previews` exports `Tayya-Studio-2-iPhone`
and `Tayya-Studio-2-iPad`. Each contains `source.json` (SHA and image hashes),
`summary.json`, `Screenshots/manifest.json` (readable scene -> PNG mapping), actual
PNG screenshots, retained xcresult ZIP and build log. These are simulator captures,
not generated promotional images. Check light/dark library/document/margin/audio/
review, tablet portrait/landscape, English, accessibility text, focus and page picker.

Local macOS: `cd DesignStudio && xcodegen generate`, then run `TayyaStudio` scheme.
Launch arguments: `--scene library|document|margin|audio|cards`, `--light|--dark`,
`--english`, `--large-type`. `--capture` freezes the sample timer for reproducible
visual inspection, without adding sleeps or changing readiness assertions.

## Interactions implemented in preview memory

- Search, section/favorite filters, new notebook form, tab destinations and opening.
- Page next/previous/thumbnails; bookmark, focus with visible exit, sidebar and split.
- Actual PDFKit document selection/zoom in Select mode; PencilKit handwriting,
  ink/pencil/highlighter/eraser/color/width, native Undo/Redo, margin text/paper styles.
- Recording state remains independent of margin. Page changes, text and manual
  markers use current time; marker activation changes page and demo playback time.
- Rename, +/-10 seconds and speed mutate demonstration state; never rename M4A.
- Reveal/assess sample flashcards. Share excerpt opens native share sheet for text.

## Explicit proposal limits

File import/export/backup/trash integration, production pen-preference adapters and card storage,
live microphone/audio playback and production per-document split
persistence are production C tasks. The isolated preview supports its own saved drafts and pen presets. Their existing stable implementations are
retained. No prototype interaction proves old M4A compatibility, background audio,
physical Office conversion or end-to-end production quality. New cards work in
preview memory, including page/file filters, and are not persisted.
No new product package/license/size cost: SwiftUI/UIKit/PDFKit/PencilKit/SF Symbols
are system frameworks. No Lottie/SnapshotTesting added for this proposal.

## Validation scope

Seven model tests first failed with expected missing-behavior assertions in run
[39353902215](https://github.com/x6one/hashiya-ios/actions/runs/39353902215)
before state implementation (7 failed tests/22 assertions). The first harness run
39353583894 did not reach tests because same-step GITHUB_ENV was unavailable;
boot now uses the selected UDID directly. No production tests were removed/skipped.
Existing full stable qualification remains run39342393075 on dbdb264; this preview
suite is separate and does not re-qualify production.

### Review handoff — 2026-10-20

Primary light/dark, English/accessibility, thumbnail and flashcard captures passed
in run39357373192 (`deb3385`), while3 cases still failed. Run39361610772 (`7c59e88`)
then passed those3 cases plus updated PDF captures on both families. The actual
variable Arabic PDF face split letter dots in extraction; public Arial document
faces retain the full required title. Marker rows now hit across their complete
rectangle; original center taps pass page8/time02:18 and real-stroke mark checks.

Actual visual review found broken words at accessibility sizes despite those prior
captures passing. Run39368421932 (`80084b0`) passes a new targeted label-line-height
and44pt test on both families. The phone dock uses3 columns at accessibility sizes;
the tablet margin title has its own row. All six retained archives were independently
SHA256/CRC checked. No successful suite was rerun just to qualify documentation.

The `Tayya Studio review gallery` workflow assembles original PNG bytes from these
three runs into one `Tayya-Studio-2-Review` artifact with an offline `index.html`,
source/test/hash manifest, design system, action map and production rollout plan.
Download/extract the artifact and open `index.html`. Each picture links to its exact
source run; earlier captures remain in `all-images.json`. Results span targeted
source revisions; no single-SHA full production qualification is claimed.

**STOP:** visual approval is required before any production redesign or migration.

See the [design specification](../docs/superpowers/specs/2026-10-20-tayya-studio-2-design.md),
[staged plan](../docs/superpowers/plans/2026-10-20-tayya-studio-2.md) and
[action map](../docs/design/tayya-studio-2-actions.md).

## Verified final polish (visual approval pending)

Visible terminology uses Notes / الملاحظات without renaming margin IDs. Native
PDFKit thumbnails share a bounded cache and serial rendering worker. Notes expands
at accessibility sizes; idle audio reserves one 44pt row and tools follow the
selected mode. Preview-only drafts, PDF text annotations and three editable pens
are saved atomically in this bundle's own sandbox; test captures normally use a
fresh temporary draft. A named `--draft-id` fixture supports actual reopen checks.
No production file or M4A is read or changed. Audio remains simulated.

Full behavior and targeted capture verification are complete. The production
integration approval gate remains.

Full DESIGN behavior source: `6d513cfcf0e7fa966dabfdb522fbe8c9e03369a8`.
Run39398450073 passed17 unit +22 UI cases per family,39/39 with zero failures/skips.
Both archives and every native PNG were independently SHA256/CRC checked. Visual
inspection then found an XCTest app.screenshot landscape crop/EXIF defect. Those
clipped captures are not the review deliverable.

Corrected capture source: `e15ffdf30577e48360e749a6e7e532d2a982b4e2`.
Run39401061917 re-captures12 relevant UI cases per family using the full native
display after actual window readiness and verifies oriented pixel/window aspect.
The workflow pins exact App/Tests/project hashes to the full39 gate; no app change,
unit replay or unrelated UI replay. Both families passed12/12 with zero failures/skips. All47 phone and48 tablet PNGs
passed independent SHA256/ZIP-CRC/source-hash and displayed-orientation checks;
representative original images were visually reviewed.
The full gate and capture source are intentionally recorded separately, without
claiming a full39 run at the capture-only SHA. Production qualification remains
separate. Gallery `compare.html` preserves all65 historical original PNGs and the
six exact user review references. The review contains160 original images:65 historical
and95 new. Open index.html or compare.html after downloading/extracting the artifact. [Polish evidence](../docs/design/tayya-studio-2-polish-review.md).
