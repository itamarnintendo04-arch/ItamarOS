# ItamarOS Demo 1.1 (Windows)

Electron desktop wrapper for [ItamarOS web emulator](https://itamaros-web-emulator.onrender.com/), **not** the native Linux operating system.

- Opens the official web emulator in a desktop window.
- The integrated web player, games, GitHub view and browser update checks run in the same window.
- Local saves are stored in Electron's sandboxed browser profile on that PC. They are not automatically synced with Chrome/Firefox/mobile.
- Requires internet at first launch; later offline content depends on what the service worker previously cached.
- No command execution, file-system permissions, native app installer, bootloader or OS replacement is provided.
- The Windows portable EXE is currently **unsigned** (Windows SmartScreen may warn; do not disable security protections to use an unknown build).

Build for Windows from this folder using Node.js/npm:
```powershell
npm install
npm run build
```
CI builds a Windows x64 executable on the dedicated Windows runner. A verified workflow run from `main` can publish a **prerelease** asset tagged `v1.1-demo` to GitHub Releases; the ItamarOS downloads page will then show it. Do not mistake the EXE for a Linux installation image.
