# ItamarOS 1.1 native apps

The native mobile/TV projects are **separate from the web emulator and Windows Electron demo**.

- [Apple source](apple/): SwiftUI source for iPhone/iPad, Apple TV, Mac, Apple Watch and Apple Vision Pro. No WebView; app-specific native UI, local games, updates, and AVKit where supported.
- [Android source](android/): Kotlin/Jetpack Compose Android phone/tablet and Android TV app. No WebView; built-in local games and Android VideoView, TV app launcher, storage settings and external-folder export.
- [Windows native WPF source](windows/): a real .NET/WPF desktop UI, pinned and running applications, native media and Windows settings. Not an Electron or WebView wrapper; no unsigned EXE public release while Avast alert is reviewed.
- [USB/device restrictions](TV_COMPATIBILITY.md): platform-specific compatibility and safe alternatives.
- [Update metadata](../updates/native-apps.json): informational manifest only; **no signed app binaries published yet**.

Native source is not a replacement phone/TV operating system. Hardware versions are distributed by approved platform signing/channel procedures after tests.
