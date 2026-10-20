# Tayya Studio 2.0 — review build

**Phase B only. Visual approval pending.** Native SwiftUI prototype, with a separate
bundle/container. `App/`, `Tests/`, `UITests/`, production `project.yml` and stable
branch are unchanged. No microphone, M4A file, disk storage or Office conversion is
used by this preview. Recording/playback progress and waveform are a **simulation**;
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

File import/export/backup/trash integration, persisted pen presets and card storage,
live microphone/audio playback and per-document split
persistence are production C tasks. Their existing stable implementations are
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

See the [design specification](../docs/superpowers/specs/2026-10-20-tayya-studio-2-design.md),
[staged plan](../docs/superpowers/plans/2026-10-20-tayya-studio-2.md) and
[action map](../docs/design/tayya-studio-2-actions.md).
