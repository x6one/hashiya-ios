# Release privacy and encryption review — 2026-10-02

Reviewed application source: 52705ef6685ee1ee9afc0c8a67ce8b319469d216.
Signed archive: Actions 36996108009; IPA SHA-256 da125ab2098ccc5a7d72cea808cf0346532c64cb55fe2bbad958c21e720b6429.
Engine source remains CollaboraOnline/online.mirror 124ecf55b0f0969b7859d2f803f0bc3a0049a4dc.

## Privacy review completed for this source
The exported signed IPA was unpacked and its app-root and ZIPFoundation privacy manifests were parsed. The app executable imports 2176 undefined symbols, matching the earlier engine inventory. The app-root manifest declares FileTimestamp C617.1/3B52.1 and SystemBootTime 35F9.1. ZIPFoundation carries its selected-file declaration. No statfs/statvfs/getattrlist imports, NSUserDefaults class import, active keyboard query, systemUptime selector or disk-space selector was identified in the signed executable inventory.

The seven direct branch sites to CFPreferencesCopyAppValue, mach_absolute_time and sysctlbyname agree in count with the earlier unstripped engine audit. Export stripping removes most internal names: the nearest retained symbols in the current inventory are NOT caller attribution. Usage is classified from the pinned unchanged sources and earlier native-api-callers.json: current-app AppleLanguages locale reading, four elapsed timer callers, and OpenSSL CPU capability detection. CFPreferences is not being treated as proof of NSUserDefaults usage or assigned an invented user-defaults reason.

Reviewed Swift import/library/PDF/audio/Office code has local storage, coordinated user-selected file access, embedded local media and optional microphone recording, with no developer telemetry, advertisements or upload client. The native bridge accepts only file URLs and disables macro execution. Engine documentLoad passes the remaining options as FilterOptions and has UpdateDocMode commented out; this is NOT a network restriction. Office external resources may be fetched by the document engine. The published policy explicitly discloses that possibility. This review does not claim that all Office files render entirely offline.

No developer data collection/tracking is declared for the described functionality. User-directed exports, Files providers, device backup services and optional support requests are described separately in the policy. This conclusion is a source/archive review, not a dynamic network penetration test or proof of every indirect path.

## Encryption classification completed for initial territories
The engine includes OpenSSL 3.5.8 and standard cryptographic implementations; do not declare no encryption or OS-only encryption. App Store Connect's App Encryption Documentation questionnaire was inspected with standard encryption selected. Selecting France requires a French encryption declaration approval form. The user explicitly selected an initial release without France; set availability to the other 174 territories. No proprietary cryptographic algorithm is added by the Tayya client.

Follow Apple's standard-encryption/non-France questionnaire for the processed build, preserving truthful encryption answers. Do not add ITSAppUsesNonExemptEncryption=false or invent an approval document or code. France stays excluded until its required documentation is supplied and accepted. Uploading does not itself prove Apple processing or beta/store approval.

## Limits and next actions
Application/native sources and bundled manifests are unchanged by this documentation commit. A new CI run must still pass both simulator suites before rebuilding/signing and uploading. Keep the existing workflow's manual publish_to_apple switch and all release/signature checks. App Store submission still requires Apple processing, saved metadata/privacy, pricing and a selected build. A physical-device smoke check remains recommended, with TestFlight making that possible.

## Official references
- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/
- https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation/
