# Tayya0.6.0 — Internal TestFlight QA

**TestFlight QA Candidate — Not Production Qualified**

The user renewed authorization for this independent QA distribution path on October28,2026. It does not qualify a public release, waive the existing simulator gates, submit an Apple review, publish a Store version, invite testers or change the current live version.

## Current status — October28

- The three requested boundaries passed5/5 per device on b69f22a, run40714306947, including a genuinely cold microphone grant followed by actual recording/save/playback. This does not establish the cause of the older uncommitted-Allow failure.
- Full candidate4952bcf run40720202150 failed one StandardType document Undo assertion on iPad; original cold cases: Phone4/4, Pad3/4. Ink remained visible and saved (one stroke); no data loss proved. Full suites/Maestro/Office correctly did not proceed. No public qualification.
- QA13 from85a973d, run40713032864, is signed, upload accepted and processedVALID, Apple build2a99e8bd-54c0-4761-9cf5-a69a09fad1d6. Missing Export Compliance blocks TestFlight; the existing key cannot PATCH this already-uploaded build (403). Do not rebuild/reupload13.
- Read-only official classification run40727182555 verified the actual published0.4.2 build usesNonExemptEncryption=false. New binaries explicitly preserve this audited exemption Boolean, verified in the exported IPA. Standard third-party OpenSSL remains included; France excluded. See encryption-classification-2026-10-28.json. This is not a no-encryption assertion.
- New QA uses the next unused Apple build number (at least14), and remains NOT PRODUCTION QUALIFIED. Actual-device drawing, Undo, Notes and microphone checks below are still required.
- A uniquely existing internal TestFlight group may receive the processed build automatically; multiple/no groups leave association unresolved. No tester invitations, external beta review or public review are performed.

## Immutable candidate and source audit

- Application source: the exact SHA in this run's `QA/source.json`, branch `integration/tayya-app-store`. An explicit `[testflight:internal]` push pins its own SHA; manual dispatch accepts an exact ancestor SHA. The historical input default is not the actual source receipt.
- Source comparison baseline: `c07e69eb49bea0588efb6c0f8d24c8b8e777c67c`; actual comprehensive workflow [40175783379](https://github.com/x6one/hashiya-ios/actions/runs/40175783379) passed tools, both regressions, both full native/exports/Maestro jobs, gallery and native Office/device packaging. The alternative focused diagnosis job was intentionally skipped.
- Office artifact:12593749685, original full run40175783379, SHA256 `4332a7be70855cd447384c8356c18a4429549bac1650a4b7c0b7f93a7ab89933`, upstream `124ecf55b0f0969b7859d2f803f0bc3a0049a4dc`. Reuse is verified and does not qualify the current app.
- Version0.6.0, bundle`com.ahmadalawi.hashiya`, iOS17+, iPhone+iPad.
- Build13 when available; otherwise Apple state determines a higher integer above all current0.6.0 train builds, including pending/invalid/expired builds. Only `CURRENT_PROJECT_VERSION` is overridden in the temporary app checkout; both original source and metadata override are attested, without spoofing GITHUB_SHA.
- `App/MarginPane.swift` has no baseline source changes. Release-preprocessed changes to MarginNotebook and DocumentThumbnails are formatting only; diagnostics there are DEBUG only. PDFWorkspace also contains previously retained page-navigation layout/focus changes. Runtime Release build settings must independently show no DEBUG and the native Office condition enabled.

## Unresolved issues — do not label them physical-device failures

Latest focused run [40678413054](https://github.com/x6one/hashiya-ios/actions/runs/40678413054), source `43d435bc7d61d55aff2d987a2ac19a2757d67da9`, passed6/8 per device with0skips. The iPhone saved-pen row exists on screen but test readiness expires before touch. The iPad Notes-close AX assertion expires although saved video shows the pane closed. Both first-microphone captures remain waiting for system permission after an automated Allow touch; completed OS grant and recorder start were not proved. These are not proven physical-device defects or an exemption from production gates. Test first-grant, denial, recording duration, stop/save and M4A playback on both real devices.

[40402135051](https://github.com/x6one/hashiya-ios/actions/runs/40402135051) failed the original iPad accessibility-size split handwriting live-pixel check: saved Drawing gained a valid stroke, but native screenshot did not show it in the original window. A separate instrumented run [40483811224](https://github.com/x6one/hashiya-ios/actions/runs/40483811224) showed ink and then missed Notes Undo, without recorded Notes action entry. The causes are unproved and must remain separate.

The healthy1/1 result [40496525554](https://github.com/x6one/hashiya-ios/actions/runs/40496525554) is not an app fix or release qualification. There is no recorded loss of the saved Stroke in these samples. Simulator results do not establish physical-device behavior.

Additional unverified source-review risks: switching pages during an unfinished stroke, manual viewport upper bounds after enlargement, and explicit toolbar-target behavior when drawing in the other pane. These were not established as causes of the saved failure; test with disposable documents only. A confirmed data-loss case stops distribution and requires a real repair.

## Manual workflow

`.github/workflows/tayya-testflight-candidate.yml` accepts manual dispatch or an explicit `[testflight:internal]` push, on the integration branch. It does not run simulator tests or Metal tracing and does not modify `ios-check.yml` or its gates.

Inputs:
- `app_source`: exact production40-character SHA, default above.
- `upload_to_apple`: true to upload after native/signing validation; false retains a signed archive/IPA without transmitting it.
- `internal_group_id`: optional existing **internal** TestFlight group for your account. Empty selects a single unambiguous existing internal group; none/multiple leaves group association for explicit setup. No group or tester is created. No testers are invited and no external beta review is requested.

Using a normally authenticated GitHub CLI:

```sh
gh workflow run tayya-testflight-candidate.yml --repo x6one/hashiya-ios --ref integration/tayya-app-store -f app_source=b11b67975576642a47de81407b363fc99601aa6b -f upload_to_apple=true
```

GitHub must recognize the dispatch-only workflow before it can be invoked. A newly added workflow absent from the default branch may require repository-owner registration there. Do not change the default branch or merge app code to work around this. The current Codex connector has commit/ref and read-only workflow tools, but no workflow_dispatch tool; the inherited CLI token is invalid. This is an execution capability limitation, not an Apple/signing result. No private key should be pasted into chat.

## What the workflow must prove

1. Exact app/controller source, engine origin/hash and build override.
2. Normal existing Apple API access and unused build allocation.
3. Independent current profile/team/bundle/expiration and matching valid signing identity/private-key check in an ephemeral keychain; no secrets in artifacts.
4. Full native Office linkage and Release iphoneos build, actual arm64/platform, microphone/PrivacyInfo/native resources, no DEBUG condition.
5. Unsigned IPA with CRC/resource checks; signed XCArchive/exported IPA with native codesign/entitlements checks.
6. SHA256 for each IPA and compressed XCArchive, retained in the QA artifact/provenance.
7. Apple validation and accepted-upload structured response, followed separately by exact0.6.0/build processing and beta-state checks. VALID processing is not sufficient when beta state is missing export compliance, expired or otherwise blocked.
8. Optional exact internal-group association confirmed by readback. No App Review or public-release API calls.

Never describe an unexecuted workflow, mocked acceptance test, or successful simulator build as a real signed IPA or Apple upload.

Review note: only the post-verification `QA/Verified` copies are published; a raw exported IPA rejected by resource/signature checks is excluded. Internal-group membership lookup currently examines at most200 builds. Large groups may need manual association/readback; this minor limitation does not qualify a false success or alter tester membership.

## Physical iPhone and iPad checklist — all pending

Use test PDFs and disposable notebooks only. Back up any existing personal library before installing the QA update with the same bundle ID. Do not erase or migrate personal files to simplify testing. Record model, iOS version, TestFlight build and orientation; retain a screen recording if a failure occurs.

| Case | Steps and required result | iPhone | iPad |
|---|---|---|---|
| PDF ink | Make several strokes with different colors, widths and pens. Ink appears and each completed stroke survives subsequent tools. | Pending | Pending |
| Notes ink | Add several strokes in separate Notes pages; verify live ink and saved ink. | Pending | Pending |
| Split/rotation | Draw, resize split, rotate both ways, expand Notes and return. Content and reading position survive. Include large Dynamic Type and dark mode. | Pending | Pending |
| Undo/Redo | Undo and redo several new strokes in each surface. Confirm which pane the target selector shows; verify the other pane is unchanged. Do not confuse new-stroke Undo after reopen with restoration of old undo history. | Pending | Pending |
| Lifecycle | Close/reopen the document, terminate/relaunch, verify all saved strokes/text/page positions. | Pending | Pending |
| Page ownership | With disposable files, check that adding/selecting Notes pages near a stroke end preserves both pages independently. Stop if any old stroke disappears from saved data. | Pending | Pending |
| Audio | Grant/deny microphone permission; record real speech, change PDF pages without stopping, create writing/manual markers, stop/save/play/seek, leave/return. Confirm actual M4A audio and correct page/time navigation. | Pending | Pending |
| Export | Export PDF and view it outside Tayya; verify every ink/text page, then re-open the source. | Pending | Pending |
| Office | Convert representative Word/Excel/PowerPoint files on device, check actual PDF bytes/content and retain originals. Native build alone is not runtime conversion proof. | Pending | Pending |
| Repeatability | Repeat the main ink/Undo/split/reopen sequence on both devices. A single pass on one device is insufficient. | Pending | Pending |

If live ink is missing, record whether saved/reopened ink also disappears; do not assume one proves the other. If Undo fails, record target pane and whether its stroke count changes. No physical-device outcome has yet been supplied or executed by Codex.

## Before public App Store approval

Resolve confirmed production defects; retain and explain the simulator failures or obtain separately reviewed evidence-based exceptions. Complete the original and new native suites (at least152/device), three Maestro flows/device, byte exports, compatibility, audio, Office, screenshots and accessibility on a final frozen source. Reuse the existing12 genuine Store compositions when still accurate, verify ar/en metadata/privacy/encryption, before App Review/public publication. The owner already authorized App Review and automatic public release on October28; do not request that permission again. Qualification remains mandatory.
