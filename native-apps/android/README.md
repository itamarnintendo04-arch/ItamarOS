# ItamarOS 1.1 — native Android and Android TV app

This is **real native Kotlin / Jetpack Compose source**. It does not embed the ItamarOS website or use a WebView.

- **Android phone/tablet**: native Home, game and saved best score, local media chooser and native player handoff, settings.
- **Android TV / Google TV**: automatically detects TV UI via UiModeManager / Leanback feature, shows native TV Streaming service buttons, opens actually installed supported apps via PackageManager when permitted, and shows native settings.
- A common source APK can be adapted to differing Android devices through device resources and screen layout. It is not guaranteed to work on every customized Android model. Min Android SDK is 26 (Android 8.0). OS/vendor-specific launch restrictions still apply.
- The original ItamarOS icon and wide TV banner are placed in Android drawable resources.

## Build and install

1. Open `native-apps/android` in a recent Android Studio with Android SDK 36 / JDK 17 and Gradle 9.3.1 supported by the selected Android Gradle Plugin.
2. Sync Gradle. Use `gradle :app:assembleDebug` or Android Studio Build to create a **test APK**.
3. Test on Android phone/tablet emulators and authorized Android TV emulator/hardware.
4. Debug APK installation must use Android's normal developer/debug deployment; app store public distribution requires independent QA and signing. No APK or AAB has yet been published as a signed release.
5. To build Google Play packages use Play Console and `bundleRelease` with legitimate signing, testing, and store policy review. This source is **not a complete operating-system installer**.

## External TV storage

The native app sets `android:installLocation="auto"`, so **if** your TV manufacturer/Android OS allows it, the system's app settings **may** allow moving the app to removable storage. The app cannot force app relocation or move Android itself to USB.

The app also provides **Choose external storage folder** using Android's Storage Access Framework: a user selects a visible USB/SD folder, then **Export app data to selected folder** writes a small JSON backup there. Some Android TVs omit the system folder picker or cannot write to a particular drive; in that case the app reports an error. No all-files permission, background copy, encryption bypass, or device storage changes.

## Streaming and privacy

TV service list detects `Asia/Jerusalem` as Israel or falls back to the Android country setting, and offers a manual region control. Streaming is TV-only. Known installed provider packages use `getLeanbackLaunchIntentForPackage`; unknown ones are never guessed or auto-installed. No location permission or precise address is requested.

Future USB boot media for an actual OS requires a certified bootloader/kernel/driver build targeting an **explicit** TV model. A simple APK/USB folder is not a replacement OS. See `../TV_COMPATIBILITY.md`.
