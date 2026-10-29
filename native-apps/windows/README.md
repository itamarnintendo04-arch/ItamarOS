# ItamarOS 1.1 — native Windows WPF demo (no WebView)

This is **genuine desktop WPF/.NET source code**, distinct from the older Electron web emulator. It does **not** use Chromium, Electron, embedded browsers or a WebView.

Features: Windows-native desktop panels, pinned/running app buttons, context-menu pin/unpin, minimize/close, file picker, local notes, native Windows MediaElement player, native game, real host Settings launchers and hardware information. State uses a small JSON file in the user's AppData folder.

## Build

Open `ItamarOS.Native.Windows.csproj` on Windows using Visual Studio with .NET desktop development workload and .NET 10 SDK, or run `dotnet build -c Debug` on Windows. Source code is not an official signed installer.

**Security:** a user reported Avast detecting an earlier, unrelated unsigned Electron EXE. This WPF source must be independently compiled, tested, scanned and reviewed, then signed, before publishing a Windows download. Do **not** override Avast detections for any unverified EXE. No new executable will be automatically published by this project.

The ItamarOS Linux OS source remains a separate Debian/KDE prototype. Running this WPF app does not install a new operating system.
