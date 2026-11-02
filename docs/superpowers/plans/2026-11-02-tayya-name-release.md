# Tayya name update Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans. The owner authorized implementation, upload, review submission and automatic release in this conversation.

**Goal:** Publish 0.6.1 with the exact App Store name طية in Arabic and English.
**Architecture:** Preserve the published d45457b App/NativeOffice trees. Change only release version/build and display-name metadata; reuse the immutable qualified Office artifact and original signing helper.
**Tech Stack:** GitHub Actions macOS, XcodeGen, existing Python and Node release helpers, App Store Connect UI.
**Spec:** Owner instructions in this conversation, 2026-11-02.

## Global Constraints
- Existing app 6818288428; bundle com.ahmadalawi.hashiya.
- Never upload build15 again. Target 0.6.1 build16 only if Apple confirms unused.
- Exact name طية in both store locales.
- Preserve images, privacy, encryption classification and France exclusion.
- No functional Swift changes or repeated native test suites.

## Review Focus
- Wrong source: compare App/NativeOffice trees and all changed paths against published source.
- Duplicate upload: check current Apple build16 both before compilation and immediately before upload.
- Wrong or expired engine: verify artifact source/run, immutable digest and tar entry bounds.
- Incorrect package: verify name, version, bundle, privacy and native resources before original signer.
- Incomplete submission: verify actual Apple state and AFTER_APPROVAL after submitting.

### Task 1: Prepare and upload the metadata-only build
Files: project.yml; .github/workflows/tayya-name-release.yml.
- [ ] Verify the only project changes are version, build and display name.
- [ ] Validate YAML, embedded Python/JS syntax and original packaging checks.
- [ ] Push isolated branch and require successful original signature/Apple validation/upload receipts.

### Task 2: Complete Apple listing and submit
- [ ] Save exact name in both locales and concise truthful release notes.
- [ ] Retain inherited screenshots/contact/privacy/territories.
- [ ] Attach processed 0.6.1(16), submit review with automatic release.
- [ ] Read back status and retain screenshot/submission URL.
