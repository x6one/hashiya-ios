# Native count, rail, and palette evidence

Read-only analysis of diagnostic source `835a27927a87a08008e0ea1067b706b520581374`, GitHub run `39154192844`, job `117753891626`, artifact `12147062835` in `x6one/hashiya-ios`. No application/test edits, CI triggers, or publication were performed.

## Integrity and scope

The completed download is `Verification/Diagnostics/LocalEvidence/count-native-12147062835.zip`: **262251351 bytes**, SHA256 **e652e7a27e3822ed5243d88f686a145804d98367afecf4a50bac6efcb285e54e**, matching the supplied expected values. Hashing occurred after the downloader reported completion. `LocalEvidence/.gitignore` contains `*` and `!.gitignore`; ZIP, extracted xcresult, logs, video, and derived frame images remain ignored. Extracted root: `Verification/Diagnostics/LocalEvidence/count-native/`.

Concise relevant native rows, XCTest log lines, state headers, palette geometries, and decoded input fields are preserved in **`Verification/Diagnostics/count-native-events.txt`** (including a follow-up presentation-timestamp verification appendix). All 17 count rows and all 10 paired rail Route/State records are included, preserving process IDs, identities, sequence numbers, wall clock and uptime. Full original native log is 123207313 bytes under the ignored extracted root; it was not copied into the report.

The diagnostic changes the unused `object: count` argument to `nil` on three count expectations while retaining their closures, predicates and 10/5/5-second deadlines; it adds bounded DEBUG logging and observers. The brief states Release application source is identical to development `c8903523e8831b24d78e87923ea966408dd5419d`. This is a diagnostic experiment, **not full preflight or proof that c890 passed**. Neither changed observation plumbing nor a later passing run retroactively supplies c890's missing native timing.

## Exact completed cases

`probe-build.log` reports **67 unit tests passed, zero failures**, 8.421 seconds test time (suite wall time 8.727 seconds). The selected UI suite completed **12 tests / 1 failure**, test time 1018.542 seconds (suite 1018.555 seconds), iPad Pro 13-inch (M5). These are the historical ten-case prefix plus the two original ink cases; no reduced-prefix equivalence is claimed.

| UI case (`LaunchTests/`) | Result | Seconds |
|---|---|---:|
| testActualDocumentPickerImportsPDF | pass | 87.554 |
| testActualDocumentPickerImportsPowerPoint | pass | 83.778 |
| testAppOwnedDocumentPickerImportsPDF | pass | 61.276 |
| testAReviewEntryProvidesCompleteLocalDemonstrationWithoutLogin | pass | 43.066 |
| testColdExternalPDFIntakeSurvivesFirstLaunchEntrance | pass | 52.360 |
| testColdExternalPDFIntakeWithReduceMotion | pass | 31.013 |
| testCreateNotebookFromLibrary | pass | 15.250 |
| testDeleteAddedDocumentAndMarginPagesThroughVisibleToolbar | pass | 47.285 |
| testDrawingToolDoesNotTurnPagesInDocumentOrSplit | pass | 47.417 |
| testExternalPDFIntakeDismissesAlreadyVisibleWelcome | pass | 50.110 |
| testIndividualInkTargetsAtAccessibilityTextSize | **fail** | **197.784** |
| testIndividualInkTargetsInDocumentAndCompactSplit | pass | 301.648 |

The sole error is `UITests/LaunchTests.swift:1096`, “Native color picker must dismiss before testing ink actions,” in **AccessibilityType-CompactSplitInk**. Accessibility document-ink operations had already completed. Standard document and split ink paths completed.

## Count path: actual native events versus XCTest observations

All captured `MarginCountTiming` events belong to Standard split process **45443**, canvas `0x104469600`, page and canvasPage both `E6BC3B73-7E67-45DC-AD79-479F0C3185A3`, main thread true throughout. No count rows for the Accessibility split exist: that path returns before its stroke when palette verification fails. These logs instrument the margin canvas, not every PDF document ink operation.

| Operation | Native action/drawing (UTC 2026-10-18) | Actual store outcome | XCTest observation evidence |
|---|---|---|---|
| Stroke 1→2 | tool-ended 18:49:29.483, count 1, uncommitted=false; drawing-did-change 29.486, count 2; persist-begin 29.486 | store-save-returned 29.526, **saved=true; inputCount=2**, callback returned 29.526 | count query begins t=223.60s / native root snapshot 18:49:30.686; query transformer 31.721; then next red-pixel expectation at t=225.67s; StrokeSaved attachment at t=230.66s says expected=2 actual=2 |
| Undo 2→1 | action begin 18:49:41.615, uptime 1871.884789792; drawing change 41.616, uptime 1871.885376333; persist-begin 41.616 | store-save-returned 41.619, uptime 1871.888704875, **saved=true; inputCount=1**; action end 41.620, count 1 | count query t=235.78s / native root snapshot 18:49:42.878; transformer 44.022; Undo attachment t=240.10s says expected=1 actual=1 |
| Redo 1→2 | action begin 18:49:51.132, uptime 1881.401486500; drawing change 51.133, uptime 1881.402344375; persist-begin 51.133 | store-save-returned 51.137, uptime 1881.406087250, **saved=true; inputCount=2**; action end 51.139, count 2 | count query t=245.28s / native root snapshot 18:49:52.365; transformer 53.181; Redo attachment t=249.55s says expected=2 actual=2 |

Uptime deltas: stroke drawing change to successful store return **40.303 ms**; undo action start to drawing change **0.587 ms**, to successful store return **3.915 ms**, whole action **4.657 ms**; redo action start to drawing change **0.858 ms**, to successful store return **4.601 ms**, whole action **6.813 ms**. The store returned before the first corresponding native count-query snapshot by about 1.160 / 1.259 / 1.228 seconds. The unchanged count predicates succeed in this diagnostic run. Exact predicate-return instants are not instrumented: query snapshots, transformer times and later state attachment times must not be relabeled as exact predicate success timestamps. No timestamps were decoded speculatively from xcresult binary strings.

This isolates a successful native sequence: the actual canvas count changes and `store.saved` becomes true before XCTest reads it. `persist-callback-returned` alone is weaker evidence; the explicit `store-save-returned saved=true` rows supply the store result. The early tool-ended count 1 is not the final stroke state: the drawing-change/save rows follow 2–43 ms later.

For c890's earlier Push iPad failure, a redo five-second failure followed by a later count 2 / FitWidth actual 2 does **not** establish native redo committed before that earlier deadline. c890 has no count timing logs. This successful instrumented run cannot distinguish whether the prior failure was delayed native work, AX observation cost, or another interleaving.

## Rail identities, enabled state, and movement limits

The observer connects in public-API order: `scroll.panGestureRecognizer`, `navigation.interactivePopGestureRecognizer`, then iOS 26 `interactiveContentPopGestureRecognizer`. Names of concrete classes do not determine which slot is content versus edge; the captured identities and API order do.

| Process / path | Scroll pan | Edge pop | Content pop | Rail viewport / latest content |
|---|---|---|---|---|
| 36159 Accessibility document | `0x10740e640` enabled true | `0x1014cb270` enabled true | `0x1014cb680` **enabled false** | (0,248,1032,61.5) / (367.5,61.5) |
| 36159 Accessibility split | `0x11efd2f70` enabled true | same | same **disabled** | (0,366,457,61.5) / (417.5,61.5) |
| 45443 Standard document | `0x106ef9490` enabled true | `0x101a4b9c0` enabled true | `0x101a4bf10` **enabled false** | (0,208,1032,60) / (328,60) |
| 45443 Standard split | `0x11f223640` enabled true | same | same **disabled** | (0,308,457,60) / (378,60) |

Both navigation recognizers report `edges=8` (right edge), and navDirection=1 (RTL); edge enabled and content disabled are distinct identities even though both concrete descriptions are `_UIParallaxTransitionPanGestureRecognizer`. Connection states show edge state 5 (failed) or 0 (possible), content state 0; rail pan state 0. Same-sequence State records show `stack=2`, `topIsOwner=true`, zero adjusted inset, enabled=true, bounces=true, and **offset=(0,0)** in every sample. Connection/disconnect records pair by **process + sequence**, since counters reset on relaunch. No rows were clipped in these paired rail records.

**Global content pop remains disabled in every captured configuration sample.** The trace contains no `gesture=` callbacks, so it supplies **no observed rail pan began/changed/ended event and no actual scroll movement**. Build logs for the two ink cases contain canvas stroke drags, not toolbar drags; all sampled toolbar content widths fit the viewport, so targets did not require horizontal scrolling. It would be incorrect to present this artifact as a successful overflow-rail drag test, to substitute the canvas stroke for a rail drag, or to conclude content pop stayed disabled at every unsampled instant. Last Accessibility split rail sample is 18:45:01.021, before the palette at 18:45:20–29; last Standard sample is 18:48:41.491, before its palette close. There are no rail callbacks around either dismissal and no evidence of a navigation pop.

## Accessibility palette failure: close reaches UI, verification misses deadline

Evidence favors a **dismissal observation/deadline failure**, not an established failure to dismiss the native palette:

- Manifest maps `4D346D43-2BF5-4550-B592-B1D10943ECA6.mp4` to the failing case; duration 197.497 seconds, recording-start timestamp **1792348949.856 = 18:42:29.856 UTC**. Verified original presentation frames show palette visible at **PTS 179.730000**, dismissing offscreen at **179.903333**, and fully absent at **179.995000, 180.200000, 180.400000**. The fully absent 179.995 sample aligns to **18:45:29.851**, 0.829s before the native AX root snapshot at 18:45:30.680. The `NativeColorPicker` screenshot manifest timestamp 18:45:28.903 aligns to video 179.047s, consistent with the still-open frame before the close. See ignored `ax-corrected-pts-contact.jpg` and original video. The earlier contact sheets labeled only by requested `-ss` time are superseded; they are not timestamp evidence.
- **Video timing verification caveat:** default sequential FFmpeg/ffprobe best-effort timestamps in this file can select the much earlier decode timestamp (DTS), e.g original `pts_time=179.498333`, `pkt_dts_time=164.828333`, `best_effort_timestamp_time=164.828333`. A default best-only frame listing therefore creates an apparent presentation gap. Repeating with demux option `-fflags +igndts` discards DTS without changing original PTS; the decoded `best_effort_timestamp_time` then equals original `pts_time`, and explicit `select=between(t,179,180.5),showinfo` yields the inspected frames above. Original PTS were cross-checked against the unmodified default full frame listing. No requested seek time was used as a substitute for an actual frame PTS. Exact 179.5, 180, or 181 frames are not assumed: nearby decoded PTS are reported explicitly.

- `FC3C8A9B-04C1-49A8-9082-F50395E1F4A1.txt` records picker **(398,186,580,650)** and visible `red 77` swatch **(641.5,653.5,45.5,45.5)**; no palette scroll was needed. Screenshot `42832294-108E-42A8-AB08-456BC16C8754.png` at 18:45:28.903 shows the selected light-red swatch, visible top-right “تم,” and open native palette. This is a 650pt-high iPad sheet despite the test's CompactSplitInk stage name; it takes the noncompact red-77 branch.
- NSKeyedArchive synthesized events show swatch down/up at raw **(355.75,664.25)** and close down/up at raw **(816,940)**, each 50ms apart, target process 36159, parent window 1376×1032, orientation field 1. In this landscape recording, `(rawY,1032−rawX)` maps these to **(664.25,676.25)** (swatch center) and **(940,216)** (visible close position). The input geometry is consistent with the visible controls; video confirms the close leads to disappearance. No precise close-frame attachment was exported, so this is a coordinate/image consistency check, not an exact hit-test reconstruction.
- XCTest close tap t=179.11s; event synthesis t=179.50s; app idle t=179.88s. Its `!picker.exists && !close.exists` predicate first logs a check at t=181.38s (the exact wait-start instant is not separately recorded). The next logged existence retries for picker and close occur at **t=185.71s**, then line-1096 failure; teardown orientation reset t=187.17s. The guard returns before checking changed color or drawing a split stroke.
- Native logs independently show root snapshot at **18:45:30.680** followed by extensive per-node no-match traversal for `nativeInkColorPicker` (e.g. 30.700, 36.834), while main thread continues serving queries. A no-match row for one node is not a completed whole-query result. Combined with video disappearance and the gap in XCTest's check logging, this supports expensive absence querying consuming the bound. It does not prove which internal XCTest/AX step exceeded it or supply the final Boolean/timing for each `exists` read.

The video-to-XCTest alignment uses the manifest and nearby screenshot attachment as a wall-clock anchor; build-log `t=` values are rounded to hundredths and attachment timestamps record collection rather than a UIKit callback. It supports dismissal before the first logged AX check, not an exact close-action callback timestamp.

The custom close action in `App/MarginNotebook.swift` sets the SwiftUI presentation binding false; this action and its binding/dismissal callbacks have no dedicated timing records. Therefore the exact internal root cause remains **bounded**: the UI visibly dismisses, but the five-second compound AX disappearance expectation does not complete in time. A claim that tapping failed, the close target was offscreen, global pop stole the tap, or palette remained mounted is unsupported by these observations. The most targeted future diagnostic would timestamp close action/binding and native presentation completion separately from each timed AX absence read; no such changes were made here.

## Collector limits and reproducibility

`ProbeEvidence/collection.json`: status collected; source 835a279; lookback 30 minutes; elapsed **45.106621542s**, timeout 90s; retained 123207313 bytes; `post_collection_truncated=false`, `writer_closed_before_stat=true`. All streamed bytes were retained, but this is a retrospective system-log collection: absence of an event still does not prove no native event occurred. Count and rail collectors each cap at 256 per process; observed counts (17 count; rail 5 seq per process) do not hit those caps. Changed-state rail sampling caps at 12 per recognizer, but there were no gesture callback samples at all.

NSLog can clip long rows; rail geometry and recognizers were deliberately split into matching Route/State records. Long PDF AX labels in system logs should not be treated as complete view inventories. Binary UI snapshot attachments around the failed wait contain only application/root records with empty children, not a full after-dismissal hierarchy; they cannot establish stale palette existence. Source, exported attachments, video, build log and native event records were used; no xcresult binary-string timestamp inference, new simulator run, or unrelated artifact download was performed.
