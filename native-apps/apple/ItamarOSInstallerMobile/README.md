# ItamarOS Installer Mobile — iPhone

## Required iPhone installer app — current desktop-companion flow

You **must first install ItamarOS Installer Mobile on the iPhone** to use its native Store, secure pairing, and installation requests. The desktop EXE alone does not add a Store tab to iOS.

1. Install a correctly signed and provisioned build of the ItamarOS Installer Mobile IPA using an authorized initial installation method.
2. Open ItamarOS Installer on Windows and start its Wi-Fi Companion server, then pair via the iPhone app's QR scanner.
3. Select an official app from the iPhone installer; the PC receives the request and requires desktop confirmation.
4. The **Installed** tab stays locked until this paired computer reports a successful installation. Its list is an app-local installation receipt, not a system-wide inventory.
5. If connection or install fails, the app shows a status/error code. An unsigned IPA needs valid signing and a detected paired device; these steps are not yet fully automated.

Signing identity metadata is synchronized from the Windows desktop; P12 files and passwords stay on the computer. The preexisting on-device certificate vault and WebView signer are legacy tooling and are not the new desktop signing workflow.

**Known limitations:** There is no one-tap automatic P12 re-signing from the desktop yet, no guarantee that Apple Devices/iTunes Wi-Fi Sync exposes the phone to the installation helper, and no way for a normal iPhone app to install arbitrary IPAs itself. This IPA build is unsigned, so it cannot serve as its own bootstrap installation.

---


Native SwiftUI catalog for all ItamarOS iOS apps, a local personal-signing certificate vault, and an iOS-authorized installation workflow.

## Importing your own signing certificate

- Open **Certificates → Import** and select your **P12**, or a **ZIP** containing the P12 and, preferably, its matching **mobileprovision** profile. You may select the profile in Files at the same time as the P12.
- A native **SecureField** prompts for the P12 password. The importer **does not look for a TXT file** and does not require one.
- A PKCS#12 import is attempted using the typed password. Certificates, passwords and optional profiles are stored encrypted with AES-GCM using an encryption key protected by the **iOS Keychain**. The password input is cleared after import.
- Use only Apple-issued certificates you own or have permission to use. No shared, leaked or revoked third-party credentials are included or offered by ItamarOS. Never publish P12 files and passwords.

## All-app catalog

The main-repository registry is `catalog/ios-apps.json`, with links to each app's individual GitHub Release. Every listed iPhone app displays **Install**. The button launches a step-by-step workflow:

1. Inspect the user's locally imported P12 and provisioning profile for **Bundle ID**, **expiration**, **signing identity** and **iPhone UDID** compatibility.
2. Download the app's **unsigned developer IPA** from its main-repository release, inspect the IPA's Info.plist, and verify that the Bundle ID matches the registry.
3. Tap **Open WebView installation**. The embedded WKWebView displays the first-party browser-based WebAssembly signer. Its **Install — sign IPA first** button runs local signing after the user explicitly chooses the authorized P12, profile, password and IPA. The app does **not** silently transmit vault secrets to the page.
4. Once the signer exports the signed IPA, it can be saved or shared from the app. **The WebView cannot itself install arbitrary IPAs**. Using this signing screen does not require a manifest or a connected computer, but installing the resulting IPA still requires Apple's approved distribution method (for example an authorized USB device installer or an OTA installation manifest hosted by an authorized distributor).

The iPhone UDID must be provided from a trusted Windows/Mac device, because iOS third-party applications cannot access the real hardware UDID directly. A matching profile is a **preflight match**, not proof of non-revocation or guaranteed installation.

## What is not implemented

**Automatic use of encrypted P12 credentials within the signer and one-tap installation of arbitrary IPAs from a WebView are not implemented (and normal WKWebView applications are not granted such installation privileges).** The app's Install buttons guide users through authorized steps and do not claim an app is installed before iOS confirms it. Full automatic signing would require a reviewed, bundled **offline** signing engine that never passes private keys to remote JavaScript.

## Source and builds

- iOS 18+; XcodeGen spec: `native-apps/apple/ItamarOSInstallerMobile/project.yml`.
- Unsigned IPA is built by `.github/workflows/itamaros-installer-mobile.yml`.
- First-party apps share the main repository; standalone Authenticator, iPhone Studio and App Studio sources are mirrored in `external-apps/`.
- Preview releases are created by `.github/workflows/publish-all-itamaros-app-releases.yml`.
- Home Screen icon options: original plus six full-spectrum multicolor RGB distortion variants (Rainbow Glitch, Prism Shift, RGB Split, Holographic, Liquid Spectrum, Neon Noise). They distort the original logo's colors rather than recoloring the entire icon uniformly.

No Apple account password, provisioning private key, P12 password TXT, or real signing certificate is committed to the repository.


## ItamarOS Store 1.6 — Discover, Apps, Games, Updates, Library, Sources

The **Store** tab replaces the old single-column ItamarOS Apps list. It includes:

- **Discover**: featured first-party app, a full gallery of official everyday apps **and games**, and a separately labeled community section.
- **Apps / Games**: filter by category; common iPhone utilities and creative apps are in Apps.
- **Updates**: check release entries for downloaded IPA files. This is not a list of all actually installed apps, which iOS does not expose to ordinary applications.
- **Library**: IPA downloads saved locally by this installer, not a claim of installation.
- **Sources**: immutable **ItamarOS Official** source + optional HTTPS JSON community sources. Add by URL or camera QR, enable, disable and remove. Source data is saved locally; no P12 keys or passwords are shared.
- App details: icon, developer, source badge, Bundle ID, version, screenshots if published, IPA download and manual export/signing handoff.

Community sources must follow `catalog/SOURCE_FORMAT.md`. They are unverified and their downloadable files are not independently security-reviewed. The installer checks the IPA structure and Bundle ID, but cannot bypass iOS signature, provisioning or installation rules.

