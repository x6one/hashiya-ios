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
- [x] Add failing tests to Tools/test_store_listing.mjs for retained status/code/title/detail/source and redaction of credentials echoed in an error.
- [x] Extend Tools/app_store_readiness.mjs minimally to preserve allowlisted, redacted Apple errors. Run affected Node contracts and syntax checks.
- [x] Add one marker-gated Ubuntu job in .github/workflows/tayya-store-listing.yml: verify app and accepted build identity/VALID; create version 0.6.0 once only if absent; read documented users role fields without PII; save sanitized report regardless of failure. No archive/upload/native tests.
- [x] Validate actionlint/diff and unchanged App tree; commit using the owner connector and inspect the actual Apple response.

## Task 2: Continue only from confirmed authority
- [ ] If version creation succeeds, reuse existing approved metadata/artwork preparation, then implement a receipt-verified metadata/review-only continuation for accepted Build15; preserve all review guards and automatic release authorization.
- [x] If authority remains unavailable, record exact Apple denial plus official available paths and request only the indispensable owner action. Never claim 0.6.0 submitted or public without Apple readback.

## Actual result
Commit 28651fef1edea32d1b61f63a0bc63196f75eb130; run 41308054842; authorization artifact 13084395807 (953bytes, SHA256 edd190184de8d12d7660218c9ddcada4326b2f519b35f76cd13c50b6f46c06f5), downloaded and CRC/hash verified. Apple explicitly says “The API key in use does not allow this request”; no0.6 version exists. Accepted15 remains VALID. Users listing succeeds with ACCOUNT_HOLDER/ADMIN, which does not reveal the independent team-key role. One fresh scope review found no important issue. Listing contracts21/21 and review contracts8/8 passed; two error-retention/redaction tests were observed RED then GREEN. No native suites or builds were repeated.

Task2 is blocked on new AppManager publishing authority: no authenticated Apple browser/key-management session, no official key-management API in the schema, and no available GitHub Secrets write capability. The owner action is replacement of the publishing credentials in existing Secrets, without exposing them here; this is a credential requirement, not another approval request. Do not retry the identical403 or run any binary job.
