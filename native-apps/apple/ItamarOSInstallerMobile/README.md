# ItamarOS Installer for iPhone (1.0)

Native SwiftUI source for an encrypted, local-only P12 / provisioning-profile vault and official ItamarOS IPA downloads.

## Where to put certificate archives

Do **not** upload private P12 signing credentials, passwords, or private keys to GitHub, ChatGPT, or another public service. On the iPhone, save each ZIP locally in Files (On My iPhone or iCloud Drive), launch ItamarOS Installer, then choose Certificates > Import. ZIP can contain .p12, password .txt, and optional .mobileprovision. The password is parsed and stored encrypted; the user does not need to retype it when a matching TXT is present.

Selected P12 credentials and matching profiles are encrypted on-device using AES-GCM; the encryption key is in iOS Keychain with this-device-only protection. Raw private keys and passwords are never bundled into the GitHub build and are never uploaded to ItamarOS services.

## Expiration and selection

On iOS 18+, the app reads certificate not-valid-after dates via the iOS Security framework and tries to read embedded provisioning-profile expiration dates for display. Automatic selection prefers the most distant known non-expired certificate. This is only a date check: it cannot guarantee the certificate has not been revoked, that the profile matches the specific device, or that an app will install successfully. The user can override selection in settings. A certificate cannot be safely asserted 'working' without actual authorized signing/install testing.

## What is available

- Import certificate ZIPs directly from iPhone Files; password TXT is applied during local import.
- Local encrypted certificate vault with manual selection and expiry display.
- Official ItamarOS app catalog discovered from the iOS Xcode targets.
- Download a published signed IPA (if one exists) and share it from Files.

**Not yet implemented:** signing IPA files inside the mobile app, silent iOS installation, automatic revocation checks or automatic replacement of expired certificates. iOS requires legitimate Apple signing/provisioning and supported distribution. The app is not linked to users' Apple IDs.

## Build

GitHub Actions: Build ItamarOS Installer Mobile IPA. Produces an unsigned iOS IPA requiring valid signing before installation. iOS 18+.

No user certificates or passwords are included in this repository.

## Custom IPA — v1.1 preflight

The **Custom IPA** tab imports a user-selected `.ipa` from Files into local Documents, reads `Payload/*.app/Info.plist`, and matches its Bundle ID to each imported provisioning profile. It checks expiration, certificate SHA-256 against `DeveloperCertificates`, app identifier and `ProvisionedDevices` against a **manually entered device UDID**. A matching entry is labeled **Preflight match**, not "working" or "installed". Unknown, expired and mismatching profiles are explicitly marked.

- Ordinary iOS apps **cannot obtain the hardware UDID** via a public API. The user must copy it manually from Finder, Apple Devices or iTunes on a trusted computer. `identifierForVendor` is not the UDID.
- Only profiles naming the provided UDID can pass strict local preflight. `ProvisionsAllDevices` enterprise profiles require extra review and are not automatically declared compatible. App Store profiles are not accepted as direct-install profiles.
- CMS profile signatures and Apple revocation are not validated locally; iOS must perform final verification.
- The app can **export/share the selected IPA** for a supported signed installation workflow on a Mac/PC; it **does not sign or directly install the IPA on iOS**. These are deliberate limits to avoid misleading installation claims.
- Certificates, TXT passwords, private keys and profile contents must **never** be uploaded publicly or committed to this repository. If an archive containing a P12 and its password was published to a public file-sharing link, immediately remove access and contact the certificate owner to rotate/revoke the exposed identity.
