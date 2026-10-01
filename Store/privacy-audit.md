# Native privacy audit — 2026-10-01

Candidate SHA-256: b8229232b61ef3c03c3c166e229eb0c3e7e01052e2c46f0360f3c9ce7115bd0e. App source: d18cc32d4e96e19acd2534992c2557938d910654. Engine: 124ecf55b0f0969b7859d2f803f0bc3a0049a4dc (CollaboraOnline/online.mirror).

The candidate lacked an app-root PrivacyInfo.xcprivacy. ZIPFoundation had its own manifest. The new app manifest declares file metadata in app storage (C617.1), explicitly selected files (3B52.1), and elapsed engine timers (35F9.1), checked against Apple's current reason documentation. CI must verify the resource at the app root.

Evidence:

- App/DocumentImport.swift reads selected-file size/type before a coordinated private copy.
- App/PageAudio.swift queries creation dates inside the app audio directory.
- Engine tools/source/datetime/ttime.cxx uses mach_absolute_time for monotonic intervals. GetUTCOffset refreshes its cache after elapsed time. The candidate also calls an NSPR interval timer.
- CFPreferencesCopyAppValue's sole direct caller is macosx_getLocale. sal/osl/unx/osxlocale.cxx reads AppleLanguages for the current app. No NSUserDefaults class import or direct app UserDefaults usage was found. Do not invent CA92.1 for system-written language preferences.
- sysctlbyname's direct caller is OPENSSL_cpuid_setup, not a boot-time query.
- No statfs/statvfs/getattrlist import was found; generic source platform branches do not prove linked usage.

Store/native-api-imports.json and Store/native-api-callers.json record observations. The nearest retained symbol supports the audit but does not prove all indirect behavior. A rebuilt archive requires a fresh API inventory.

The initial no-tracking/no-collected-data manifest matches app code with no telemetry, advertising or client uploads. Final native indirect-access and external-resource review remains pending; privacy_audit_complete is false. Macro execution is disabled. UpdateDocMode is commented out in engine documentLoad and is not a verified network restriction.

Official sources:

- https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons
- https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- https://developer.apple.com/documentation/corefoundation/preferences-utilities
