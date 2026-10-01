# Encryption status — 2026-10-01

The native engine includes OpenSSL. Pinned engine/download.lst identifies openssl-3.5.8.tar.gz, SHA-256 a8f84a39918ec6415ce765d9b429d313ba97b8143169c172e734b9514464f5b2. Linked OPENSSL_cpuid_setup calls sysctlbyname for CPU detection.

Third-party cryptographic code prevents asserting the entire app uses only OS cryptography without further review. No ITSAppUsesNonExemptEncryption=false has been added. Exemption, encrypted-document behavior, declarations and distribution territories must be determined through Apple's questionnaire. encryption_classification_complete remains false. An inspection archive does not resolve export compliance or automatically upload.

Official sources:

- https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance
- https://developer.apple.com/help/app-store-connect/reference/export-compliance-documentation-for-encryption/
- https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations
