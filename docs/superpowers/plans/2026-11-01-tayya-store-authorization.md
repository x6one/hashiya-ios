# Tayya existing-build Store authorization

> Execute inline with superpowers:executing-plans. The owner's 2026-11-01 request authorizes the scoped Apple operation and publication; no routine approval checkpoint is required.

**Goal:** Resolve the actual Apple version-creation denial, then publish existing accepted Build 15 if access permits.
**Architecture:** Reuse the existing Apple JWT client and Store controller. Preserve sanitized official error fields, execute one bounded version-creation request, and inspect documented user-role read access. No binary build/upload or production changes.
**Tech:** Node.js, existing GitHub Actions Ubuntu job, Apple official OpenAPI 4.5.1.
**Spec:** Latest owner request; Store/publication.json identifies app 6818288428, source d45457bdd216265b11d58ba844fcda22fb6297d9, accepted build f708ce7c-681a-4d88-aa82-2b01fc9c5274.

## Constraints and review focus
- Keep Build 15, successful release gates, production source and stable branches unchanged.
- Never persist keys, JWTs, authorization headers or user email addresses.
- A team key's role cannot be inferred from user roles or a generic 403 alone.
- No authenticated Apple browser session is provisioned; key management is absent from the official OpenAPI. Do not invent private endpoints or bypass 2FA.
- Local GitHub token belongs to iahmadxxx with pull-only access; Secrets metadata returns 403. Owner connector permits repository writes but exposes no Secrets administration operation.

## Task 1: Safely retain official denial evidence
- [ ] Add failing tests to Tools/test_store_listing.mjs for retained status/code/title/detail/source and redaction of credentials echoed in an error.
- [ ] Extend Tools/app_store_readiness.mjs minimally to preserve allowlisted, redacted Apple errors. Run affected Node contracts and syntax checks.
- [ ] Add one marker-gated Ubuntu job in .github/workflows/tayya-store-listing.yml: verify app and accepted build identity/VALID; create version 0.6.0 once only if absent; read documented users role fields without PII; save sanitized report regardless of failure. No archive/upload/native tests.
- [ ] Validate actionlint/diff and unchanged App tree; commit using the owner connector and inspect the actual Apple response.

## Task 2: Continue only from confirmed authority
- [ ] If version creation succeeds, reuse existing approved metadata/artwork preparation, then implement a receipt-verified metadata/review-only continuation for accepted Build15; preserve all review guards and automatic release authorization.
- [ ] If authority remains unavailable, record exact Apple denial plus official available paths and request only the indispensable owner action. Never claim 0.6.0 submitted or public without Apple readback.
