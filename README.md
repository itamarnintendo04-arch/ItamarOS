# ◈ ItamarOS — Version 1.1

**ItamarOS** is a personal operating-system project featuring a PC desktop edition, an installable desktop demonstration, and a responsive browser emulator.

[**Open ItamarOS Demo**](https://itamaros-web-emulator.onrender.com/) · [**Downloads**](https://itamaros-web-emulator.onrender.com/downloads.html) · [**Installation guide**](INSTALLATION.md) · [**GitHub Releases**](https://github.com/itamarnintendo04-arch/ItamarOS/releases)

## Editions

| Edition | Package | Status | Purpose |
| --- | --- | --- | --- |
| **ItamarOS PC 1.1** | Bootable `.iso` for x64 PCs | Experimental build pipeline; compatibility and installation testing required | Complete desktop environment with device settings and installer |
| **ItamarOS Demo — Windows** | Portable `.exe` | Published unsigned demo prerelease | Try the interface without replacing your existing system |
| **ItamarOS Demo — Mac** | `.dmg` for Intel and Apple Silicon | CI build tested; unsigned preview artifacts | Try the interface in a separate Mac application |
| **ItamarOS Demo — browser** | Web application / PWA | Live on Render | Explore the adaptive interface on compatible devices |

**Important:** The ISO build recipe and native components are under development. A successful CI build does not mean the image has been tested for booting or installation. **Do not overwrite a primary computer or disk with an unverified image.** The Windows/Mac downloads run a demonstration and do not replace the device's operating system.

## ItamarOS PC — features

- **Desktop and system settings:** KDE Plasma interface, display, resolution and scaling, touchpad and mouse, keyboard, Bluetooth, Wi-Fi and Ethernet, audio and microphone, printers, power and battery, storage and connected devices, accounts, privacy, appearance and accessibility.
- **Automatic hardware identification:** read-only CPU, logical cores, available memory, manufacturer, PC model, graphics, drives, battery, firmware boot mode and network adapters. Manufacturer-specific labels appear where detected.
- **Safe installation review:** the ItamarOS Preinstall app shows the detected computer hardware and requires deliberate confirmation before opening the full installer. It does not select, repartition or erase disks itself.
- **Software Updates:** update notifications based on a version manifest stored in the official GitHub repository, with manual checks and deferred installation. Regular application/security updates are handled by signed system package repositories and KDE Discover.
- **ItamarOS Player:** opens the installed VLC media engine for local playback and supported media formats.
- **YouTube WebView:** opens the official YouTube website in its own browser application window. Requires internet; not affiliated with YouTube/Google.
- **ItamarOS Games:** built-in no-download mini-games with browser-local saved scores and progress.
- **GitHub:** project source and available release assets.

See [the PC edition build notes](native/README.md) and [the safe installation instructions](INSTALLATION.md) for technical setup and known limitations.

## Emulator features

The web emulator features a touch-friendly desktop, phone, tablet and TV layout selected automatically using information made available by the browser. Browser identification is approximate; exact vendor, CPU model and storage specifications are only available through the installed PC system.

The emulator provides settings, local files, a media player, saved games, YouTube WebView launcher, a TV-only region-aware streaming app launcher, a GitHub app and Software Updates. The demo stores data in the browser or app profile; it is **not** a full installation environment.

- Browser: [https://itamaros-web-emulator.onrender.com/](https://itamaros-web-emulator.onrender.com/)
- Portable Windows desktop demo: [GitHub Releases](https://github.com/itamarnintendo04-arch/ItamarOS/releases/tag/v1.1-demo)
- Mac installer: [Official Releases](https://github.com/itamarnintendo04-arch/ItamarOS/releases) when the reviewed DMG assets are published; [CI builds](https://github.com/itamarnintendo04-arch/ItamarOS/actions/workflows/mac-demo.yml) may have test artifacts.
- Experimental ISO build: [CI workflow](https://github.com/itamarnintendo04-arch/ItamarOS/actions/workflows/native-iso.yml) produces VM-testing artifacts only.

## Versions and updates

The version sequence starts with `.0` and continues with `.1`, `.5`, and `.9`:

`1.0 → 1.1 → 1.5 → 1.9 → 2.0 → 2.1 → 2.5 → 2.9 → 3.0`

1. Develop features in the [`updates` branch](https://github.com/itamarnintendo04-arch/ItamarOS/tree/updates).
2. Run automated tests and review changes in a pull request.
3. Merge to the stable [`main` branch](https://github.com/itamarnintendo04-arch/ItamarOS/tree/main).
4. Render automatically deploys the website. Supported installed applications check for available updates from the official manifests.

See [versioning](native/VERSIONING.md) and [update architecture](updates/README.md).

## Development

The repository separates the native PC edition (`native/`), desktop demo packages (`desktop/`, `desktop-app/`), and web emulator (`index.html`, `apps/`). The web demo can run without a server API for its included games.

Validation commands:

```bash
node tests/smoke.cjs
python3 -m unittest discover -s tests -p "native-smoke.py"
```

System image builds must run in a dedicated test environment with sufficient resources. Refer to `native/README.md` for package and build dependencies. Do not run unreviewed disk-installation procedures on devices with valuable data.

## Project and licensing

This is an independent community development project. The YouTube WebView are **not affiliated with Google or YouTube**. Third-party components retain their own licenses, trademarks and attribution requirements. A file in a GitHub Release is not a security certification; verify checksums, supported hardware and provenance before installation.

## Protected system apps and shared files

All 37 built-in web emulator apps now have individual original SVG icons and no uninstall action in ItamarOS Store. Native Linux launchers and their icons live in system-owned locations; only a privileged Linux administrator can override their files. Unlike the demo, the Linux distribution includes a [Shared Storage](DUAL_BOOT_STORAGE.md) inspector for accessing **already mounted** NTFS/exFAT data volumes. Linux and Windows still require separate system partitions: shared files occupy disk space once, and personal app/profile settings are not automatically synchronized.

## Official ItamarOS visual identity

The [original blue/cyan ItamarOS master logo](assets/branding/itamaros-logo.png) is the shared brand across the web emulator, Android/iOS home-screen web app, Windows/Linux/Mac desktop demo build sources, and native Linux UI sources. The favicon, 192/512 mobile icons, maskable PWA image, Windows ICO, and native system icon are derived from the same original artwork. The native **About ItamarOS** window, Control Center and preinstall screen use the same emblem. See [branding files](assets/branding/) and [native build notes](native/README.md).

Existing desktop downloads are not retroactively updated: rebuild and publish the corresponding desktop release to embed the new application icon. Installing the browser demo as a home-screen shortcut uses the new manifest icon once supported browsers refresh their metadata.

## Streaming on TVs only

**TV Streaming** appears only when the browser detects a TV interface. Country is estimated automatically from the browser's **time zone**, with language/region fallback. This is not GPS, does not reveal precise location, and may be inaccurate on VPNs or custom time-zone settings. The service list offers global services and selected country-specific services (Israel: כאן BOX, yes+, HOT; USA: Hulu, Peacock). A manual country correction is available.

Native app launching is only supported from a compatible **installed** Tizen or webOS TV web app with platform APIs, or an Android TV native wrapper exposing the `ItamarOSTVNative.launchApp` bridge. The current browser demo is **not** an installed TV app, so it cannot guarantee launching installed streaming apps. Unknown/unverified provider IDs have no direct launch; users must open those apps from the TV home screen. No website redirect is substituted for native app launch.

See [TV app integration notes](tv/README.md).
