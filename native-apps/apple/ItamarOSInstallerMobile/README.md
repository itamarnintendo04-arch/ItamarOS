# ItamarOS Installer Mobile — iPhone

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
3. Open the existing **first-party browser-based WebAssembly signer**. The signer currently requires the user to explicitly choose their authorized P12, profile and IPA files again. The app does **not** silently transmit vault secrets to the website.
4. **No manifest required:** export the signed IPA to your Windows or Mac computer, connect your unlocked and trusted iPhone using USB, and open **ItamarOS Installer → My iPhone → Install Local IPA over USB**. Apple's device services and iOS verify the signature and provisioning. The mobile app cannot install another app silently.

The iPhone UDID must be provided from a trusted Windows/Mac device, because iOS third-party applications cannot access the real hardware UDID directly. A matching profile is a **preflight match**, not proof of non-revocation or guaranteed installation.

## What is not implemented

**Automatic use of encrypted P12 credentials within the signer, silent on-device signing and one-tap installation of arbitrary unsigned IPAs are not implemented.** The app's Install buttons guide users through authorized steps and do not claim an app is installed before iOS confirms it. Full automatic signing would require a reviewed, bundled **offline** signing engine that never passes private keys to remote JavaScript.

## Source and builds

- iOS 18+; XcodeGen spec: `native-apps/apple/ItamarOSInstallerMobile/project.yml`.
- Unsigned IPA is built by `.github/workflows/itamaros-installer-mobile.yml`.
- First-party apps share the main repository; standalone Authenticator, iPhone Studio and App Studio sources are mirrored in `external-apps/`.
- Preview releases are created by `.github/workflows/publish-all-itamaros-app-releases.yml`.
- Home Screen icon options: original plus six full-spectrum multicolor RGB distortion variants (Rainbow Glitch, Prism Shift, RGB Split, Holographic, Liquid Spectrum, Neon Noise). They distort the original logo's colors rather than recoloring the entire icon uniformly.

No Apple account password, provisioning private key, P12 password TXT, or real signing certificate is committed to the repository.
