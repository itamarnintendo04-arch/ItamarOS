# ItamarOS 1.1 — real SwiftUI iPhone/iPad and Apple TV apps

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
- Apple TV: native remote-friendly streaming service catalog, with approximate country detection and manual correction. tvOS **does not provide an unrestricted API to launch other providers' installed apps**, so tapping a service displays the correct limitation, rather than opening arbitrary apps.
- Does **not** install ItamarOS as a replacement for iOS/tvOS, mount USB drives as an app install destination or modify system Settings. No universal USB OS installer exists for Apple TV.

Privacy: no location permission, no account requirement, and no private device data sent to ItamarOS services.

Additional targets include a standalone native **macOS** app (not Electron), **Apple Watch** with a compact native game, and **visionOS**. HomePod does not accept general-purpose third-party apps. These new targets are **source code only**, not validated signed apps or App Store listings.
