# Native160-image audit

Frozen source efd63d3 / gallery39403683099. Original PNGs were read, never edited.

# iPhone original-image audit

Read-only audit: all 77 iPhone records covered, 72 unique SHA256 image contents viewed through view_image. Current source e15ffdf30577e48360e749a6e7e532d2a982b4e2: 47 records / 45 unique contents. Historical: 30 records / 29 unique contents, with two contents shared across historical/current. No PNG was transformed, cropped, rewritten, or regenerated.

## Current bounded findings

- images/155-iPhone.png: extreme Notes portrait header title visibly ends in ellipsis on its second line; preview subtitle also ellipsized. Bottom recording label ellipsized; four huge mode labels consume the row and the leftmost Notes label is visibly clipped against the left edge.
- images/157-iPhone.png: extreme document portrait uses the same crowded bottom dock; leftmost Notes label clipped, recording label ellipsized. Header title fits across two lines; no title ellipsis here. Contextual pen controls still remain individually visible.
- images/160-iPhone.png: thumbnails 1–9 and partial next row repeat the same accounting title, equation strip, paragraphs and five bars; page numbers/selection differ. This proves repeated sample page bodies in this capture, not that the thumbnail renderer uses a wrong PDF page.
- images/119-iPhone.png, images/128-iPhone.png, images/143-iPhone.png: full app/status chrome and PDF are diagonal with large black corner wedges. Also present in images/117-iPhone.png (slight), images/130-iPhone.png and images/148-iPhone.png. All stored sizes are 1206×2622, EXIF Orientation=8. EXIF rotation is a right-angle instruction and cannot alone cause the arbitrary diagonal angle/black wedges. This is capture-time raster/compositor evidence, consistent with catching rotation animation; exact originating cause (capture synchronization versus live UI transform) cannot be proved from screenshots alone. Do not treat as settled landscape UI layout evidence. Level landscape counterparts include126,142,145,146,152,154,156.
- images/150-iPhone.png: normal text contextual toolbar fits cleanly; images/136-iPhone.png and138-iPhone.png show accessible dock wrapping to two rows rather than horizontal overflow. Extreme155/157 are the stronger current dock defect.

## Historical distinction

- images/038-iPhone.png,040-iPhone.png,058-iPhone.png: older accessible dock kept all five oversized modes on a single row, splitting Pages awkwardly; current136/138 improve this with two rows.
- images/064-iPhone.png and065-iPhone.png already demonstrate historical two-row accessible dock treatment. Current extreme155/157 still overflow at the larger extreme setting.
- images/045-iPhone.png shows historical generic document icons instead of actual page previews. Current160 has actual rendered previews but visually repeated sample bodies.
- Older normal document and notes captures have different chrome/content treatments; they are historical evidence, not new current regressions. Approved palette and general identity require no change.

## Filename coverage

Every row below is visually covered; duplicate rows reference an identical SHA representative actually viewed. All metadata read directly from original PNGs.

|Filename|Era|Scene|Viewed representative|EXIF orientation|
|---|---|---|---|---|
|images/026-iPhone.png|Historical|Dark-cards-Portrait|images/114-iPhone.png|1|
|images/027-iPhone.png|Historical|Dark-audio-Portrait|images/027-iPhone.png|1|
|images/028-iPhone.png|Historical|Dark-margin-Portrait|images/028-iPhone.png|1|
|images/029-iPhone.png|Historical|Dark-document-Portrait|images/029-iPhone.png|1|
|images/030-iPhone.png|Historical|Dark-library-Portrait|images/030-iPhone.png|1|
|images/031-iPhone.png|Historical|Light-cards-Portrait|images/123-iPhone.png|1|
|images/032-iPhone.png|Historical|Light-audio-Portrait|images/032-iPhone.png|1|
|images/033-iPhone.png|Historical|Light-margin-Portrait|images/033-iPhone.png|1|
|images/034-iPhone.png|Historical|Light-document-Portrait|images/034-iPhone.png|1|
|images/035-iPhone.png|Historical|Light-library-Portrait|images/035-iPhone.png|1|
|images/036-iPhone.png|Historical|Accessibility-audio|images/036-iPhone.png|1|
|images/037-iPhone.png|Historical|English-audio|images/037-iPhone.png|1|
|images/038-iPhone.png|Historical|Accessibility-margin|images/038-iPhone.png|1|
|images/039-iPhone.png|Historical|English-margin|images/039-iPhone.png|1|
|images/040-iPhone.png|Historical|Accessibility-document|images/040-iPhone.png|1|
|images/041-iPhone.png|Historical|English-document|images/041-iPhone.png|1|
|images/042-iPhone.png|Historical|Accessibility-library|images/042-iPhone.png|1|
|images/043-iPhone.png|Historical|English-library|images/043-iPhone.png|1|
|images/044-iPhone.png|Historical|Review-AnswerRevealed|images/044-iPhone.png|1|
|images/045-iPhone.png|Historical|Document-PageThumbnails|images/045-iPhone.png|1|
|images/046-iPhone.png|Historical|Audio-SavedPlaybackAndMarkers|images/046-iPhone.png|1|
|images/055-iPhone.png|Historical|Audio-MarkerSeek-02m18s-Page8|images/055-iPhone.png|1|
|images/056-iPhone.png|Historical|Document-Focus|images/056-iPhone.png|1|
|images/057-iPhone.png|Historical|Audio-SavedPlaybackAndMarkers|images/046-iPhone.png|1|
|images/058-iPhone.png|Historical|Accessibility-document|images/058-iPhone.png|1|
|images/059-iPhone.png|Historical|English-document|images/059-iPhone.png|1|
|images/060-iPhone.png|Historical|Dark-document-Portrait|images/060-iPhone.png|1|
|images/061-iPhone.png|Historical|Light-document-Portrait|images/061-iPhone.png|1|
|images/064-iPhone.png|Historical|Accessibility-margin|images/064-iPhone.png|1|
|images/065-iPhone.png|Historical|Accessibility-document|images/065-iPhone.png|1|
|images/114-iPhone.png|Current|Dark-cards-Portrait|images/114-iPhone.png|1|
|images/115-iPhone.png|Current|Dark-audio-Landscape|images/115-iPhone.png|8|
|images/116-iPhone.png|Current|Dark-audio-Portrait|images/116-iPhone.png|1|
|images/117-iPhone.png|Current|Dark-margin-Landscape|images/117-iPhone.png|8|
|images/118-iPhone.png|Current|Dark-margin-Portrait|images/118-iPhone.png|1|
|images/119-iPhone.png|Current|Dark-document-Landscape|images/119-iPhone.png|8|
|images/120-iPhone.png|Current|Dark-document-Portrait|images/120-iPhone.png|1|
|images/121-iPhone.png|Current|Dark-library-Landscape|images/121-iPhone.png|8|
|images/122-iPhone.png|Current|Dark-library-Portrait|images/122-iPhone.png|1|
|images/123-iPhone.png|Current|Light-cards-Portrait|images/123-iPhone.png|1|
|images/124-iPhone.png|Current|Light-audio-Landscape|images/124-iPhone.png|8|
|images/125-iPhone.png|Current|Light-audio-Portrait|images/125-iPhone.png|1|
|images/126-iPhone.png|Current|Light-margin-Landscape|images/126-iPhone.png|8|
|images/127-iPhone.png|Current|Light-margin-Portrait|images/127-iPhone.png|1|
|images/128-iPhone.png|Current|Light-document-Landscape|images/128-iPhone.png|8|
|images/129-iPhone.png|Current|Light-document-Portrait|images/129-iPhone.png|1|
|images/130-iPhone.png|Current|Light-library-Landscape|images/130-iPhone.png|8|
|images/131-iPhone.png|Current|Light-library-Portrait|images/131-iPhone.png|1|
|images/132-iPhone.png|Current|Polish-CompactAccessible-DocumentFocus-English-Dark|images/132-iPhone.png|8|
|images/133-iPhone.png|Current|Polish-CompactAccessible-DocumentFocus-Arabic-Light|images/133-iPhone.png|8|
|images/134-iPhone.png|Current|Accessibility-audio|images/134-iPhone.png|1|
|images/135-iPhone.png|Current|English-audio|images/135-iPhone.png|1|
|images/136-iPhone.png|Current|Accessibility-margin|images/136-iPhone.png|1|
|images/137-iPhone.png|Current|English-margin|images/137-iPhone.png|1|
|images/138-iPhone.png|Current|Accessibility-document|images/138-iPhone.png|1|
|images/139-iPhone.png|Current|English-document|images/139-iPhone.png|1|
|images/140-iPhone.png|Current|Accessibility-library|images/140-iPhone.png|1|
|images/141-iPhone.png|Current|English-library|images/141-iPhone.png|1|
|images/142-iPhone.png|Current|Final-Dark-StandaloneNotes-Landscape|images/142-iPhone.png|8|
|images/143-iPhone.png|Current|Final-Dark-Focus-Landscape|images/143-iPhone.png|8|
|images/144-iPhone.png|Current|Final-Dark-Focus-Portrait|images/144-iPhone.png|1|
|images/145-iPhone.png|Current|Final-Light-StandaloneNotes-Landscape|images/145-iPhone.png|8|
|images/146-iPhone.png|Current|Final-Light-Focus-Landscape|images/146-iPhone.png|8|
|images/147-iPhone.png|Current|Final-Light-Focus-Portrait|images/147-iPhone.png|1|
|images/148-iPhone.png|Current|Polish-Accessibility-Landscape|images/148-iPhone.png|8|
|images/149-iPhone.png|Current|Polish-Pen-Context|images/129-iPhone.png|1|
|images/150-iPhone.png|Current|Polish-Text-Context|images/150-iPhone.png|1|
|images/151-iPhone.png|Current|Polish-Favorite-Pens|images/151-iPhone.png|1|
|images/152-iPhone.png|Current|ExtremeType-library-Landscape|images/152-iPhone.png|8|
|images/153-iPhone.png|Current|ExtremeType-library-Portrait|images/153-iPhone.png|1|
|images/154-iPhone.png|Current|ExtremeType-margin-Landscape|images/154-iPhone.png|8|
|images/155-iPhone.png|Current|ExtremeType-margin-Portrait|images/155-iPhone.png|1|
|images/156-iPhone.png|Current|ExtremeType-document-Landscape|images/156-iPhone.png|8|
|images/157-iPhone.png|Current|ExtremeType-document-Portrait|images/157-iPhone.png|1|
|images/158-iPhone.png|Current|Polish-Accessibility-Library|images/140-iPhone.png|1|
|images/159-iPhone.png|Current|Polish-Audio-ActiveMarker|images/159-iPhone.png|1|
|images/160-iPhone.png|Current|Document-PageThumbnails|images/160-iPhone.png|1|

# iPad visual evidence audit

Read-only audit of all 83 iPad records in `visual-approval-reference/all-images.json`, including all 48 latest records at e15ffdf30577e48360e749a6e7e532d2a982b4e2. All 77 unique SHA images were inspected as original PNGs with view_image. No images modified, reoriented, cropped, or combined. No code edits/tests/network.

## Actionable current findings

- **AX5 portrait dock crowding — UI evidence, high confidence.** `images/108-iPad.png` (ExtremeType Notes portrait) has five bottom labels packed side-by-side with almost no separation: Pages, Notes, Select, Text, Pen. Selected Notes background hugs the huge label; neighboring labels visually run together. `images/110-iPad.png` (ExtremeType document portrait) repeats this. Compare comfortably spaced normal `images/079-iPad.png`, AX2 `images/086-iPad.png` and `images/088-iPad.png`; landscape AX5 `images/107-iPad.png` and `images/109-iPad.png` has enough horizontal room. Bounded fix: let existing dock adapt its layout to available width and Dynamic Type while preserving accessible text and current palette. Top header text in these current images is large but fully visible; no demonstrated header collision.
- **AX5 library sidebar — UI evidence, medium confidence / secondary scope.** `images/106-iPad.png` wraps University/Personal into broken word fragments in the fixed sidebar; `images/105-iPad.png` truncates sidebar heading and folder labels despite its wider main canvas. Current AX2 library `images/090-iPad.png` (=111) is readable. Treat as Dynamic Type layout polish only if library is within authorized scope; do not redesign.
- **Page distinctness remains unresolved — source/fixture/rendering unknown.** `images/113-iPad.png` now has real-looking previews rather than historical generic file icons (`images/024-iPad.png`). However all 24 previews show almost the same heading/body/equation/five-bar chart. `images/071-iPad.png`, `images/080-iPad.png` (pages 6–8) and `images/092-iPad.png`, `images/096-iPad.png` (pages 11–13) also repeat this content. Footers/page numbers vary. Inspect the actual PDF page content and thumbnail source before attributing reuse to UI; this evidence alone cannot distinguish intentionally repeated fixture pages from wrong-page thumbnails.
- **Contextual tools look coherent at captured normal size.** `images/103-iPad.png` shows text-specific editing/alignment/color/size controls; `images/104-iPad.png` favorite pens sheet is readable. `images/102-iPad.png` is byte-identical to normal document `images/081-iPad.png`, so it is coverage of a duplicate screenshot, not independent proof of a distinct pen-context interaction. No current captured contextual-toolbar overlap observed.

## Orientation evidence

Every iPad PNG has raw pixel dimensions 1668×2420. Every record labeled Landscape has EXIF Orientation=8, which implies displayed dimensions 2420×1668 (ratio ~1.451, inverse of raw ~0.689). Every portrait has Orientation=1. Raw dimensions alone therefore do not prove a UI orientation defect.

All 23 landscape originals inspected: `004-iPad.png`, `006-iPad.png`, `011-iPad.png`, `013-iPad.png`, `053-iPad.png`, `067-iPad.png`, `069-iPad.png`, `071-iPad.png`, `073-iPad.png`, `076-iPad.png`, `078-iPad.png`, `080-iPad.png`, `082-iPad.png`, `092-iPad.png`, `093-iPad.png`, `094-iPad.png`, `096-iPad.png`, `097-iPad.png`, `098-iPad.png`, `100-iPad.png`, `105-iPad.png`, `107-iPad.png`, `109-iPad.png`.

Historical `images/006-iPad.png` and `images/013-iPad.png` display the entire screen sideways, including the OS status bar, after EXIF is honored. Their displayed landscape rectangle contains a rotated portrait composition. This supports a capture/orientation metadata/pixel mismatch rather than an app subview rotation bug; screenshots alone cannot locate the faulty capture step. Historical document landscapes 004/011/053 and **all 18 latest landscapes** display upright with a horizontal status bar. Do not change current UI based on historical 006/013.

## Historical vs current

Historical `images/017-iPad.png`, `images/019-iPad.png`, `images/050-iPad.png`, `images/062-iPad.png`, `images/063-iPad.png` show note-body lines clipped beneath the equation block and, in earlier split views, awkwardly wrapped Notes headers. Current AX2 `images/086-iPad.png` / `images/088-iPad.png` expand notes and show both bullet lines clearly. Current AX5 `images/108-iPad.png` / `images/110-iPad.png` also show readable body and equation with no body/equation collision in portrait. Landscape AX5 shows less body in its shorter content area; static captures cannot prove scroll reachability, so do not label clipped viewport extent as hidden/unreachable content without interaction evidence.

## Complete filename coverage

All filenames below are under `visual-approval-reference/images/`. Listed originals were actually opened with view_image; duplicate aliases are explicitly linked to the same SHA representative.

Latest originals viewed: `066-iPad.png`, `067-iPad.png`, `068-iPad.png`, `069-iPad.png`, `070-iPad.png`, `071-iPad.png`, `072-iPad.png`, `073-iPad.png`, `074-iPad.png`, `075-iPad.png`, `076-iPad.png`, `077-iPad.png`, `078-iPad.png`, `079-iPad.png`, `080-iPad.png`, `081-iPad.png`, `082-iPad.png`, `083-iPad.png`, `084-iPad.png`, `085-iPad.png`, `086-iPad.png`, `087-iPad.png`, `088-iPad.png`, `089-iPad.png`, `090-iPad.png`, `091-iPad.png`, `092-iPad.png`, `093-iPad.png`, `094-iPad.png`, `095-iPad.png`, `096-iPad.png`, `097-iPad.png`, `098-iPad.png`, `099-iPad.png`, `100-iPad.png`, `103-iPad.png`, `104-iPad.png`, `105-iPad.png`, `106-iPad.png`, `107-iPad.png`, `108-iPad.png`, `109-iPad.png`, `110-iPad.png`, `112-iPad.png`, `113-iPad.png`.

Latest duplicate aliases covered: `101-iPad.png` = `088-iPad.png`; `102-iPad.png` = `081-iPad.png`; `111-iPad.png` = `090-iPad.png`.

Historical originals viewed: `001-iPad.png`, `002-iPad.png`, `003-iPad.png`, `004-iPad.png`, `005-iPad.png`, `006-iPad.png`, `007-iPad.png`, `009-iPad.png`, `010-iPad.png`, `011-iPad.png`, `012-iPad.png`, `013-iPad.png`, `014-iPad.png`, `015-iPad.png`, `016-iPad.png`, `017-iPad.png`, `018-iPad.png`, `019-iPad.png`, `020-iPad.png`, `021-iPad.png`, `022-iPad.png`, `023-iPad.png`, `024-iPad.png`, `025-iPad.png`, `047-iPad.png`, `048-iPad.png`, `050-iPad.png`, `051-iPad.png`, `052-iPad.png`, `053-iPad.png`, `054-iPad.png`, `062-iPad.png`, `063-iPad.png`.

Historical duplicate aliases covered: `008-iPad.png` = `075-iPad.png`; `049-iPad.png` = `025-iPad.png`. Also `001-iPad.png` = `066-iPad.png` (both opened). Thus 78 original file opens representing 77 distinct images cover all 83 records. No iPad record remains unviewed or uncovered by a SHA-identical representative.
