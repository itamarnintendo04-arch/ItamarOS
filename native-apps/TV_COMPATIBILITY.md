# ItamarOS Native 1.1 — device and USB compatibility

There is **no single file** that can replace the operating system on all TVs, phones or Apple devices. Hardware kernels, drivers, secure boot, encryption and vendor support differ.

| Device category | Native ItamarOS app source | Official installation route | Replacing device OS by USB | External app/data storage |
| --- | --- | --- | --- | --- |
| iPhone and iPad | SwiftUI iOS/iPadOS | Apple developer-signed app, TestFlight or App Store when published | **Not supported** | Files app may offer compatible USB storage for user-selected files, not app relocation |
| Apple TV | SwiftUI tvOS | Apple-approved tvOS app distribution, developer Xcode build | **Not supported** | tvOS controls installed-app storage; app cannot move itself to a USB stick |
| Mac | Native SwiftUI macOS + existing Electron demo | Signed/notarized Mac app or authorized development build | Mac native app does not replace macOS | Files can be stored on external volumes permitted by macOS |
| Apple Watch | Native SwiftUI watchOS | Apple-approved app distribution and supported pairing | **Not supported** | No arbitrary USB storage installation |
| Apple Vision Pro | Native SwiftUI visionOS | Apple-approved app distribution | **Not supported** | App sandbox and files provider limitations |
| HomePod | No third-party general-purpose app runtime | No general ItamarOS installation | **Not supported** | Not applicable |
| Android phone/tablet | Kotlin / Jetpack Compose | Signed Android app via compatible store or authorized developer test device | **No universal replacement image** | SAF may write user files to removable drives where providers permit |
| Android TV / Google TV | Kotlin / Jetpack Compose (TV mode) | Signed Android TV APK through the TV's approved distribution or developer testing | **No universal USB image** | System may allow app relocation on some TVs; `installLocation=auto` requests eligibility, but manufacturer decides. Native SAF supports user-selected USB data backup if picker/provider exists |
| Samsung Tizen TV / LG webOS TV | Web demo and experimental vendor app-launch integration; no native app package yet | Manufacturer's official developer packaging/channel | **No universal USB installer** | Manufacturer-specific; not implemented |
| PC (amd64) | Experimental Debian/KDE native source | Only after verified ISO, test VM and compatible bootable PC media | Model-dependent boot device, **not for TVs** | Windows/Linux shared NTFS/exFAT data supported as read-only detection and explicit use |

## USB storage clarification

Two different actions have different restrictions:

1. **Move/download the Android TV app to external storage**: only if the TV's Android OS supports this, usually through the official app info/storage interface. The app can request `installLocation="auto"` but **cannot force movement** and cannot move the operating system.
2. **Export user-generated app data to a USB/SD folder**: Android SAF asks the user to choose an existing writable folder; if the TV exposes the USB drive in its file picker, the app can write its own small backup file. Some TV models do not expose external folders. The exported JSON is not an app installer.

For Apple TV, both third-party app relocation to USB and USB-based OS replacement are unavailable through public tvOS APIs. Apple-approved installation/testing uses signed binaries, App Store/TestFlight where supported, Xcode/Apple Configurator.

## No unsafe firmware or universal boot file

This repo intentionally **does not** contain a TV USB firmware flasher, manufacturer signature bypass, bootloader unlock utility, or script that formats USB media/TV drives. Building actual replacement OS images would require a separate vendor-specific, explicitly supported hardware project, its documented recovery process and independent validation. Never test an unverified system image on a working family TV.

## Device-specific branding

Original ItamarOS art is adapted for **iOS, iPadOS, tvOS, watchOS, macOS, visionOS, Android, and Android TV**. The assets are platform-specific dimensions, adaptive/rounded icons, Android TV banners and tvOS shelf artwork, not different unrelated logo designs. App Store icon/layer validation still requires native platform builds and review.

## Status

These are **real native source projects**, not prebuilt APK/IPA/TV packages. Do not list source files as installed apps. No native app has been fully tested, signed, published or installed on every listed device.
