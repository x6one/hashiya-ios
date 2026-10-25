# Tayya App Store Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline. The user has authorized routine implementation and distribution; preserve the existing approved design and source evidence.

**Goal:** Deliver branded, accurate App Store imagery and upload the compliant signed production app when credentials and mandatory gates permit.

**Architecture:** Keep c07e69e frozen on the original integration branch. Use integration/tayya-app-store for release metadata, a narrowly scoped privacy declaration, and native screenshot automation. Read credentials only inside CI; use the existing native Office distribution path.

**Tech Stack:** SwiftUI/XCTest production captures on macOS, Python/JSON, HTML/CSS/Chromium, GitHub Actions, App Store Connect API.

**Spec:** docs/superpowers/specs/2026-10-25-tayya-app-store-design.md

## Global constraints

Version 0.6.0; build 13; com.ahmadalawi.hashiya; iOS 17; iPhone+iPad. No user-data/schema change, stable merge, paid service, or secret disclosure. No artificial UI screenshots or unsupported marketing claims. All original tests remain.

## Review focus

- Actual device capture and PNG dimensions must agree; don't relabel large-phone UI as a medium-phone capture.
- Arabic shaping, line breaks, full controls and phone-size readability must survive rendering.
- Every screenshot must match the production app, with source hashes retained.
- API credentials may be missing or scoped incorrectly; read-only probes must fail safely and log no key/JWT.
- Build13 may already exist at Apple; inspect before attempting duplicate upload or changing the version.

### 1. Release readiness

- [x] Check existing Apple records and CI credentials read-only through a narrowly scoped workflow.
- [x] Add the failing app-owned UserDefaults privacy-manifest contract to Tools/test_release_tools.py; observe RED.
- [x] Add CA92.1 to App/Resources/PrivacyInfo.xcprivacy; run the focused check and existing Tools suite.
- [x] Update Store release audit and current reviewer copy using real controls. Preserve prior crypto classification and excluded territory.

### 2. Designed imagery

- [ ] Capture the medium iPhone through existing StudioProductionCaptureTests on macOS; retain raw attachments/summary and exact source/device.
- [x] Create Store/Studio2 artwork copy, licensed fonts, editable HTML/CSS renderer and manifest. Reuse the verified iPad originals.
- [ ] Render six Arabic images per device, inspect at full and phone size, refine once, and verify RGB/no alpha, required dimensions, text bounds and input hashes.
- [ ] Package the PNGs, editable source, provenance and browsable HTML together as one artifact.

### 3. Apple distribution

- [ ] If the privacy resource changes, freeze one store candidate and satisfy same-source native gates before signing. No repeated diagnostics or relaxed assertions.
- [ ] Use the existing native Office archive/sign/validate/upload workflow, after read-only Apple state and credentials succeed.
- [ ] Upload localized images and current metadata, preserving existing contact data and release settings; verify processing and report the actual state.
- [ ] If a credential or external-access requirement blocks upload, deliver all completed assets and identify the exact missing permission/input without inventing success.


### Store-publication guard review

- [x] Real filesystem/PNG/hash validator:5 checks observed RED before implementation, then GREEN.
- [x] Review identified retry of FAILED assets and replacement-order drift. Added healthy-completed reuse plus FAILED/AWAITING_UPLOAD rejection (2 observed RED); all12 Node checks now GREEN. API ordering is explicitly patched and then read back. Required native-job and actual-producer run URL checks also passed after observed RED.
- [x] Independent read-only review found no remaining important issues; actual Apple protocol/write capability remains unverified until the guarded content workflow runs.
- [ ] After final capture/native qualification, create store/tayya-app-store-content with Store/publication.json containing actual immutable source/run/App-tree values. This branch changes Store content and its isolated publication helper only; do not modify production, build or signing code or move the frozen candidate.

Current source-of-truth task ledger: .superpowers/sdd/2026-10-25-tayya-app-store/current.json (ignored local continuation state). No Apple upload or review submission has occurred during preparation.
