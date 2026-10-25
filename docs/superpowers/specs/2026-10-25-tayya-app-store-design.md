# Tayya App Store preparation

The user now explicitly authorizes App Store distribution, superseding the earlier no-Apple restriction. Preserve the qualified integration branch at c07e69eb49bea0588efb6c0f8d24c8b8e777c67c and work on integration/tayya-app-store. No stable/main merge, paid service, version/build change, credential disclosure, or automatic generation of additional Apple keys.

## Visual direction

Use actual production screenshots inside a restrained branded composition: paper #F8F7F3, ink #244C43, copper #C48F68, white, and selection #E9EFEA. Reuse the native folded ribbon mark. Arabic headings use locally available, licensed Noto Kufi Arabic; supporting copy uses Noto Sans Arabic. All six images show the actual app, with unaltered source PNGs and provenance hashes. Do not generate UI, fabricate capabilities, add price/rank claims, or obscure controls with overlays.

Six Arabic stories: library, PDF handwriting, page-linked Notes, recording markers, real thumbnails, focus. Use separate native iPhone/iPad captures; show the iPad split and the phone's expanded Notes where appropriate. Produce RGB PNGs without transparency, editable HTML, a phone-friendly preview, provenance and checksums, and a ZIP.

## Approaches and standing authorization

Branded typography around genuine screenshots meets both the user's explicit design direction and Apple's accurate-metadata rule. Plain screenshots omit the requested designed identity; synthetic app mockups misrepresent the app and are rejected. The user has already delegated routine decisions and approved Tayya's identity: proceed inline without a new design-approval round, while delivering concrete visuals for review. Six Arabic images are my proposed initial localization, not a user-specified count.

## Distribution constraints

Apple's current required phone category is Dynamic Island medium (1206x2622 accepted); iPad 13-inch accepts 2064x2752. Capture the actual medium phone using the existing production capture tests instead of stretching the 1320x2868 captures into a different device class. Existing 13-inch captures are reusable because application UI is unchanged.

The qualified bundle is 0.6.0 (13), com.ahmadalawi.hashiya, iOS 17, phone+tablet. It is unsigned. Use the existing native Office signing pipeline and CI secrets only. First probe credential presence and App Store records read-only, without logging tokens or key material. Do not infer present credentials from stale Store/signing-status.json; Store/metadata.json records a later successful upload.

Current production uses UserDefaults/AppStorage for preferences, but PrivacyInfo.xcprivacy lacks the UserDefaults declaration. Add only the truthful app-owned-storage reason CA92.1, protected by a failing contract check. No storage migration or behavior change. Refresh release notes and reviewer instructions to describe the integrated UI; retain existing Apple contact details and France exclusion. Do not invent contact data or claim physical microphone/Office runtime verification.

Official references, checked 2026-10-25: developer.apple.com/help/app-review/guideline-reference/2-3-3-screenshots/ ; developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/ ; developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons .
