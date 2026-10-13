# Tayya paper studio visual refinement

User approved all eight in-chat proposals and requested implementation and the final result. Continue source c2b3ff72b00742edcedb2e6013e3cdd6e12bfcad on work/tayya-calm-workspace.

## Accepted design
1. Paper and ink palette: warm ivory workspace, white document pages, deep green selected controls, restrained copper details; adaptive dark equivalents with readable contrast.
2. Library covers: stable color per notebook, genuine PDF first-page thumbnail, stronger title/secondary hierarchy and consistently aligned card rows. Preserve thumbnail background worker/cache.
3. Fold identity: a small native folded page corner on covers and the same recognizable fold in branding. Keep existing app icon.
4. Quiet adaptive toolbar: clearly grouped actions, consistent icon/label treatment and selected state, accessible colors. Fit iPhone and iPad without hiding existing functionality.
5. Arabic typography/alignment: system Arabic fonts and Dynamic Type; consistent baselines, readable captions, minimum 44-point interactive targets. Margin mode labels remain readable in narrow landscape.
6. Split presentation: thin separator with obvious grip and warm paper note area. Preserve split hit target/drag semantics and all reader/ink geometry safeguards.
7. Independent recording strip: real recording duration and bounded level indication, obvious start/stop/status, preserved recording/permission/error journeys. Recording never opens or resizes margins. Keep frequent meter invalidation local. Preserve clips and link formats; coordinate old/linked playback to avoid overlapping audio while retaining old files.
8. Brief motion: first-launch paper-to-fold entrance with exact credit 'By Ahmad Al-awi'; native opacity/transform microtransitions with Reduce Motion honored. Do not animate drawing geometry or add ongoing decorative animation.

## Delivery and constraints
- SwiftUI/PDFKit/PencilKit, iOS 17 minimum, bundle com.ahmadalawi.hashiya, iPhone/iPad. No new package, service, paid API, data schema or migration.
- Version 0.6.0, build 13. No Apple upload or PR merge.
- Keep accessibility identifiers and existing flow labels used by XCTest/XCUITest/Maestro. Stable object identities and cached rendering remain intact.
- CPU-sensitive PDF/ink code is out of cosmetic scope except existing view chrome; changing a toolbar must not reset page, zoom or canvas.
- Verify complete XCTest/XCUITest and three Maestro flows on each device family for final source. Review actual current-source screenshots, then native Office unsigned and archive-only signed IPA.

## Scope decisions
Covers get deterministic colors from notebook UUID, not a new persisted customization model. Waveform is driven by recording metering, never a fabricated microphone trace. System fonts avoid new font licensing/dependencies. Existing neutral UI may be refined; no rebuilding of the application.
