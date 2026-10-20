# Tayya Studio final visual approval

Base: efd63d3f9ea1b0b461b80ef95e4dde839329a88d. Stable dbdb264 is untouched.

The user's bounded brief authorizes execution through screenshots, then requires visual approval before integration. No additional design approval gate is needed during this round. Existing Superpowers instructions apply; no tools or dependencies are installed again.

## Evidence and hypotheses

All160 original PNG records (149 unique pixel files) were inspected, split by device. Reports: /workspace/approval-phone-audit.md and /workspace/approval-pad-audit.md. Images108/155/157 still show AX5 header/dock crowding. iPhone119/128/143 contain diagonal compositor frames despite correct EXIF display dimensions; window geometry readiness does not imply presentation readiness. Image160 uses real PDFKit thumbnails, but the fixture repeats the same content and document-wide invalidation prevents proving selective refresh.

## Execution

1. Add baseline-compatible StudioApprovalTests for diverse native PDF pages, per-page cache retention, structural changes and concurrent240-page rendering. Add AX5 UI geometry regression. Publish targeted RED only, inspect assertion failures.
2. Adapt AX5 header/dock/context controls without shrinking type or changing identifiers. Keep AX2 labels and existing tests. Capture only stable original full-display pixels. Create actual text/table/image/ink/blank PDF pages, preserve the24-page sample and page7. Cache by stable page identity and generation; coalesce concurrent requests. Files: StudioWorkspace/Components/Audio/Library/Document/Thumbnails and focused tests as necessary.
3. Targeted GREEN includes new tests and related existing viewport, context, notes, audio and saved-pen regressions. Inspect original landscape PNGs. Then run the complete updated Studio suite on iPhone and iPad at one source SHA. No production gate or microphone claims. Obtain a fresh code review and address findings before claiming completion.
4. Freeze the previous160-image collection as before evidence. Publish new original PNGs with per-image scene/device/orientation/font/theme/language/source SHA/test link, mobile comparison HTML and one ZIP. Validate all links, hashes, ZIP CRC and source/test summaries. Stop for visual approval; no merge, production edits, IPA or Apple upload.

## Completion rules

Actual failing assertions must precede behavioral repairs. A compile failure is not RED. No rerun of identical failure without a new hypothesis. Existing tests retain their requirements. No image cropping/rotation after capture. Audio is simulated. Native iOS execution occurs only on existing GitHub Actions macOS runners. Preserve resume ledger and isolated worktree until approval.
