# Tayya internal TestFlight QA candidate implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Produce and, when manual dispatch is available, upload an explicitly unqualified internal QA build without falsifying or changing production qualification.
**Architecture:** A dispatch-only macOS workflow checks out one immutable production SHA. Reuse the verified c07 Office artifact and original native linker/project/distribution tools; retain verified archives explicitly. A small QA controller reuses the existing Apple authentication client for read-only build allocation/status and an optional existing internal-group association only.
**Tech Stack:** GitHub Actions, Xcode26.2+, XcodeGen, existing Python/native Office tools, Node built-ins, existing signing/API secrets.
**Spec:** User instruction `/workspace/attachments/f5291bd3-9a05-444e-b5c8-5ddebe6feed4/Pasted text.txt`; portable QA scope and device checklist in `Store/testflight-qa.md`.

## Global Constraints

- Source branch `integration/tayya-app-store`; current app pin b11b67975576642a47de81407b363fc99601aa6b. No main/stable merge.
- Version0.6.0, bundlecom.ahmadalawi.hashiya, iOS17, iPhone+iPad. Build13 when available; otherwise next valid integer above used train builds, recorded as a build-metadata-only override.
- Workflow `.github/workflows/tayya-testflight-candidate.yml` has workflow_dispatch only; no simulator run, Metal, new diagnostic tooling, or alteration of comprehensive gates.
- Retain original simulator failures as unresolved, not physical-device proof. Disposable fixtures only for QA; no public qualification claim.
- Use existing signing/API secrets privately, no new keys or secret output. No external testers, invites, App Review, live Store changes or publication.
- No known recorded Stroke-data loss; code-review edge risks remain explicitly unverified and require device fixture testing, not production claims.

## Review Focus

- Wrong checkout/build provenance: record controller SHA, exact application SHA/tree, build override and engine artifact independently.
- Duplicate/in-flight Apple build: serialize workflow; allocation includes all processing states and fails closed on malformed/pagination errors.
- Unusable/expired signing material: independent identity/profile check before archive using original private temporary-keychain mechanism.
- Artifact safety: retain only verified archive on explicit request, no private signing directory; hash IPA/archive/unsigned package.
- TestFlight readiness vs upload acceptance: exact version/build processing and beta detail; missing compliance is blocked, not success; group association only explicit internal group.

### Task1: Existing-tool extensions and QA orchestration

**Files:** Tools/distribute_native_app.py, Tools/test_release_tools.py, Tools/app_store_readiness.mjs, Tools/testflight_candidate.mjs, Tools/test_testflight_candidate.mjs.
**Interfaces:** Existing distribution CLI keeps defaults. Add explicit preserve-archive and verify-signing-only modes. Export existing Apple client without running readiness on import. QA module provides selectQABuild(rows), select/status/assign CLI.
- [x] Write failing archive retention and QA build/status/group tests; run and verify expected missing-feature failures.
- [x] Implement minimal helper changes; preserve default production guards and cleanup.
- [x] Run all existing Python Tools tests, existing Store Node tests and new QA tests. No Apple operation is represented by mocks as actual acceptance.

### Task2: Dispatch-only candidate workflow and review packet

**Files:** .github/workflows/tayya-testflight-candidate.yml, Store/testflight-qa.md, Verification/Diagnostics/testflight-candidate-source-audit.json.
**Consumes:** Task1 CLI; c07 source/run40175783379 engine artifact12593749685 (265998445B, SHA2564332a7be70855cd447384c8356c18a4429549bac1650a4b7c0b7f93a7ab89933), upstream124ecf55b0f0969b7859d2f803f0bc3a0049a4dc.
- [x] Implement exact-source and verified/safe engine extraction, Release iphoneos build, unsigned packaging, signing preflight, archive/sign/verify/upload and separate actual processing checks.
- [x] Keep credentials limited to specific steps; archive only validated output; preserve accurate not-production-qualified receipt.
- [x] Run actionlint, embedded script syntax, diff checks and unchanged-App/gate checks. Review the complete change once before commit.

### Task3: Commit, manual execution and handoff

- [ ] Commit reviewed tested changes together on the authorized integration branch without a full-test marker.
- [ ] Attempt only supported normal manual dispatch; no token extraction, event spoofing, default-branch changes or automatic trigger workaround.
- [ ] If dispatch available, monitor actual build, verify artifacts/Apple response/exact processed build; analyze actual failure before retry.
- [ ] If unavailable, deliver committed workflow, exact dispatch command/link and precise missing capability. Do not claim IPA/signing/upload/TestFlight/device tests occurred.
