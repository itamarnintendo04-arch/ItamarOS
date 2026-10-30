# ItamarOS 1.5 — real SwiftUI iPhone/iPad and Apple TV apps

These are **native app sources**; no WebView, Electron, or hosted-site wrapper is used. The interface is built with SwiftUI. iPhone/iPad player uses native AVKit, games store local progress, settings use AppStorage, and release checks use URLSession.

**Targets:** `ItamarOSiOS` for iOS/iPadOS 17+, `ItamarOStvOS` for tvOS 17+, `ItamarOSmacOS` for macOS 14+, `ItamarOSvisionOS` for visionOS 2+, and `ItamarOSwatchOS` for watchOS 10+. watchOS uses its own SwiftUI Watch app; other targets share the native SwiftUI implementation. Support depends on an appropriate SDK and developer signing. The Apple App Store's app thinning selects architecture/device-appropriate assets once a signed app is published. See `project.yml`.

## Build on Mac

1. Install a supported Xcode version and [XcodeGen](https://github.com/yonaskolb/XcodeGen).
2. From this folder, run `xcodegen generate`.
3. Open `ItamarOSNative.xcodeproj` in Xcode, select the desired iOS/tvOS target, choose a Simulator or authorized device and configure **Signing & Capabilities** with a valid Apple development team.
4. Build and run in Xcode. Shipping through TestFlight/App Store requires the appropriate Apple account and review.

No signed IPA, TestFlight build, or App Store listing has been published yet. The source is not itself an installable IPA.

## Device-specific logo

The original ItamarOS blue/cyan emblem is used in the `BrandMark` asset, 1024px iOS AppIcon artwork, and Apple TV-wide icon/top shelf artwork. tvOS layered icon validation and all asset catalog/App Store review requirements still need to be checked using Xcode on Mac.

## What it does and does not do

- Home, native Number Guess and Tic-Tac-Toe games, settings with persistent preferences, version checks using the official GitHub manifest.
- iPhone/iPad: native AVKit player for local files selected in the system file importer.
- iPhone/iPad: IPA Files tab allows local import of a user-selected .ipa file and explicit sharing via the iOS share sheet. Importing/sharing does not sign, install or update apps. iOS does not provide a general third-party API for automatic arbitrary IPA installation.
- Apple TV: native remote-friendly streaming service catalog, with approximate country detection and manual correction. tvOS **does not provide an unrestricted API to launch other providers' installed apps**, so tapping a service displays the correct limitation, rather than opening arbitrary apps.
- Does **not** install ItamarOS as a replacement for iOS/tvOS, mount USB drives as an app install destination or modify system Settings. No universal USB OS installer exists for Apple TV.

Privacy: no location permission, no account requirement, and no private device data sent to ItamarOS services.

Additional targets include a standalone native **macOS** app (not Electron), **Apple Watch** with a compact native game, and **visionOS**. HomePod does not accept general-purpose third-party apps. These new targets are **source code only**, not validated signed apps or App Store listings.

## IPA file workflow

The native iOS/iPadOS `IPAImportView.swift` accepts one locally selected `.ipa` file from the system Files picker. The file is copied into the app's temporary cache (rather than being sent to ItamarOS servers), then the user may explicitly share that file with another installed tool via iOS Share Sheet. The file's extension and non-zero size are checked; this **does not verify signatures or prove the archive is trustworthy**. Other file types are refused.

There is intentionally **no remote signing-service API, automatic install button, credential upload, or promise of free arbitrary IPA signing**. iOS requires Apple-approved code signing/provisioning and a supported installation/distribution route. Apple allows free personal on-device testing through Xcode on a Mac using a Personal Team, with short-lived provisioning, but regular public app distribution requires an eligible account and route. Do not collect Apple passwords or private signing certificates in this feature.

## Local Apple profiles (maximum five)

The iPhone/iPad Home screen includes native **Sign in with Apple** and a **local profile list**. The app may save up to five previously authorized Apple user identifiers with optional local display names, and lets the user select an authorized profile, rename, sign out locally, and remove any saved profile. Records stay in the device-only, when-unlocked Apple Keychain and are not uploaded to ItamarOS services. No Apple passwords, private certificates, authorization codes, or identity tokens are saved.

**Platform limitation:** Apple's native Sign in with Apple authentication works with the iCloud Apple Account currently signed in to the iPhone. The five saved entries are not five concurrently active Apple sessions; only one local profile is active. Switching profiles requires a valid Apple authorization, and logging out locally does not log the user out of system iCloud or revoke Apple's app authorization. Users may revoke authorization through the Apple Account settings.

**Important:** Sign in with Apple is an identity authentication feature and does not sign IPA files. The profile count is an ItamarOS interface limit, **not** a way to raise Apple's free Personal Team limits (three installed developer apps per device, seven-day provisioning). Signed installation still requires a separate valid Apple-issued signing/provisioning mechanism. The Sign in with Apple entitlement must be enabled for the actual developer team's App ID before the feature can work on a signed device build; an unsigned development IPA cannot use it.
