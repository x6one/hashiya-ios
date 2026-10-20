# Tayya Studio2.0 — final visual qualification

Status: complete native Studio qualification passed on both devices at e94c2cbb6f6914e0ebb21ded090beaa54013e4df. User visual approval is pending; no integration or production release claim.

Production remains unchanged at dbdb264bf86a6606be095aad22cd303ad01e2071. Only the isolated DesignStudio branch is affected. No BundleID/signing/user-storage change, merge, Apple upload or IPA. Audio is an in-memory simulation, not proof of microphone or M4A handling.

## Bounded repairs

1. AX5 editor/header clipping: whole naturally wrapping title, secondary menu, five44pt core icon controls with full VoiceOver names; normal/AX2 labels retained. Context rails use stable44pt height. Readable AX5 iPad sidebar with scrolling.
2. Landscape capture: original119/128/143 have19.78–20.07% black pixels and diagonal whole chrome despite correct EXIF/aspect. Capture now waits for actual window orientation and consecutive equal full-screen pixel buffers. Original PNGs remain unedited. No speculative SwiftUI rotation rewrite.
3. PDF thumbnails: actual24-page native fixture retainspage7 and adds distinct text/table/rasterimage/nativeInk/nearlyblank firstfivepages. Selective UUIDincarnations prevent stale edited/deleted/reinserted renders; unchanged thumbnails retain identity, concurrent requests coalesce, serial snapshot rendering and80image/24MiB cache remain bounded. Native240page regression covers lazy requests.

## Evidence trail

- RED0ab9c3e / [39476024870](https://github.com/x6one/hashiya-ios/actions/runs/39476024870): four new native cache/fixture tests failed each family; phone tool bounds failed.
- First repair361049a / [39477868311](https://github.com/x6one/hashiya-ios/actions/runs/39477868311):11/12 each; all7UI passed. New raw Arabic-title comparison failed. Native PDFKit diagnostics subsequently proved presentation forms and U+06CC medialYeh CMap; new exact-title test normalizes only those equivalents, original PDF assertion unchanged.
- Deterministic reinsertionRED2f6aacd / [39480080336](https://github.com/x6one/hashiya-ios/actions/runs/39480080336): key collision failed before stored UUID repair.
- Target6ee386c / [39481700687](https://github.com/x6one/hashiya-ios/actions/runs/39481700687):15/15 each,0fail/skip.
- Full e72b05c / [39483968667](https://github.com/x6one/hashiya-ios/actions/runs/39483968667):45/46 each,0skip. Phone:context-frame predicate after nondefault Pencil/6pt/purple in EnglishdarkAX5. Pad:original Notes saved-readiness predicate. Allothercases passed.
- Diagnostic-only fffba6e / [39487876941](https://github.com/x6one/hashiya-ios/actions/runs/39487876941):2/2 each. Actual frame exactly equal through Text/Select/Pen in allthree configurations. Phone failure did not reproduce; exact original cause remains unproven, no speculative app geometry repair.
- Save trace proves successful disk write and main saved publication4.63s after mutation, following4.289s graphics pipeline stall;5s periodic predicate missed the publication. Repair observes actual saved event using retained Combine subscription plus async XCTest fulfillment, keeping5s and all PDF round-trip assertions.
- e98a64a / [39489844842](https://github.com/x6one/hashiya-ios/actions/runs/39489844842):targeted3/3cases per family passed,0fail/skip. PDF test now requires closed color sheet and consecutive stable positive geometry before baseline, and checksx/y/width/height within1pt. No assertions weakened.
- Fresh code review found one cache race, fixed with deterministic RED and UUIDincarnations; later reviewed readiness changes found no actionable issue.
- Localgallery10/10tests passed; historical160originals recovered after environment reset using verified ZIP SHA b0d74e9e3296169c7a3b5878c29e71202b9602dd5e31a5e0ed21ab70738f8adc. Source/run/test/hash provenance retained.

- Final full Studio gate [39491602063](https://github.com/x6one/hashiya-ios/actions/runs/39491602063) at e94c2cbb6f6914e0ebb21ded090beaa54013e4df: EACH family22/22unit+24/24UI=46/46,0failures/skips/expectedfailures. Source frozen after targeted3/3 each. SwiftFormat/SwiftLint passed on the macOS runners.

## Visual review

Full e72 original captures reviewed:phone66records/53unique,17unique landscapes;pad70records/56unique,18unique landscapes. No concrete layout or rotation blocker remains. An apparent absent chart in default image-tool previews was disproved by original-resolution views and exact copper pixels in all four AX5contextPNGs; no app repair warranted. Static screenshots do not establish scrolling/touch behavior; native tests cover those separately.

## Final delivery

- Final137nativePNGrecords:67iPhone/54unique,70iPad/56unique. Native launch/window metadata attached to every image. SHA256/ZIP-CRC and every PNG hash verified. No crop/rotation/rewrite. Final landscape records18phone+19pad verified upright.
- Phone65records byte-identical to reviewed e72; both new originals reviewed at original resolution. Tablet70records byte-identical to reviewed e72. Detailed coverage in Native-Visual-Audit.md.
- Original160beforeimages retained unchanged, same numbering/source/test/hash/bytes. Total297original image records. index.html contains only final-source captures; history.html preserves all before/after; compare.html pairs actual original references. Every caption shows scene/device/orientation/font/theme/language/fullsourceSHA/testlink.
- Native24-page PDF supplied for each family. First five pages demonstrate selectable text, a table, embedded image, native Ink annotation and nearly blank page. Native cache/edit/insert/delete/concurrency/reinsertion regressions passed, including240-page fixture.
- Final native phone archive SHA256:5451198479f1cb6426176a5bfa50c61f9fbd2239b832c9f865c589340f6c3d6b.
- Final native tablet archive SHA256:d4def3c9cd56ed3fd354ddd31cdcda4ebe73656acb178091fc2c73df672000b9.
- Gallery contracts10/10passed. The uploaded handoffZIP has its own GitHub artifact digest, checked separately after download. Gallery publication changes only tools/docs, so native app/test/project trees remain identical to the tested source.

After visual approval, phaseC must integrate the real editor/audio and verify user-data preservation and actual recording. Production68/32/Maestro intentionally not rerun for the isolated prototype. Audio remains simulated; no microphone/M4A/device recording proof. No final IPA, merge or Apple upload.
