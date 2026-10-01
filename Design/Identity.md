# طَيّة — Tayya

Name selected by the user on 2026-10-01. The name describes a paper fold, connecting reading, handwriting and a personal library. The bundle identifier and Xcode product remain unchanged so upgrades can retain existing documents.

## Visual direction

- Forest ink: #123F38; warm ivory: #F6ECD8; terracotta fold: #D27A54.
- Native dynamic colors in App/TayyaTheme.swift adapt paper, surfaces and controls to dark appearance. PDF contents keep their original colors.
- The 1024px opaque RGB app icon lives at App/Assets.xcassets/AppIcon.appiconset/AppIcon.png. iOS supplies the rounded mask.
- The opening uses a native folded ribbon outline, then a filled fold with a short perspective settling motion. Library content loads underneath the overlay. Reduce Motion skips the introduction.
- System Arabic typography, right-to-left library content, adaptive iPad columns, native navigation and a quiet reading workspace.

## Icon generation

Created with the built-in image generation tool, then normalized to a 1024 × 1024 RGB PNG for the asset catalog. The selected icon is committed with the app.

Final prompt:

> Use case: logo-brand. Create the final iOS app icon for an Arabic PDF annotation and notebook app named Tayya (طَيّة, a fold). One single opaque square icon, 1024x1024, full bleed dark forest green #123F38 background. In the center a memorable sculptural folded paper ribbon mark: warm ivory #F6ECD8 broad horizontal upper fold connecting into a descending diagonal fold and clean vertical tapered paper tail, subtly suggesting a T and the act of folding a page. One small burnt terracotta #D27A54 underside visible at a fold seam. Editorial, elegant, modern Arabic stationery brand, flat geometric silhouette with very restrained natural fold depth, exceptionally readable at tiny size. Generous negative space, mark fills about 62 percent of square. No text, letters, pencil, book, generic document outline, gradient background, glossy plastic, badges, outer rounded corners, framing, mockup, watermark. The square itself must reach the canvas edges; iOS supplies the corner mask.
