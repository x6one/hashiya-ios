# Encryption status — 2026-10-01

The native engine includes OpenSSL. Pinned engine/download.lst identifies openssl-3.5.8.tar.gz, SHA-256 a8f84a39918ec6415ce765d9b429d313ba97b8143169c172e734b9514464f5b2. Linked OPENSSL_cpuid_setup calls sysctlbyname for CPU detection.

Third-party cryptographic code prevents asserting the entire app uses only OS cryptography. The October2 classification audit and the actual Apple read-only receipt from October28 are recorded in encryption-classification-2026-10-28.json. Apple's published0.4.2 build has usesNonExemptEncryption=false; the native engine and cryptography are unchanged. New binaries therefore explicitly declare ITSAppUsesNonExemptEncryption=false, meaning no non-exempt encryption, not no encryption. France remains excluded. The exported IPA must preserve this exact Boolean. This does not clear already-uploaded QA13, whose post-upload PATCH was denied403, nor does it qualify a public release.

Official sources:

- https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance
- https://developer.apple.com/help/app-store-connect/reference/export-compliance-documentation-for-encryption/
- https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations
