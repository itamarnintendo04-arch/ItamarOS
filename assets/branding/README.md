# Official ItamarOS visual identity

This folder contains the **same original blue/cyan ItamarOS emblem and wordmark** used across the project. The original 1254×1254 RGBA artwork is preserved in the user's ChatGPT file library at `/ItamarOS/Brand/ItamarOS-original-logo.png`. The following repository assets are size- and palette-optimized copies from that source:

| File | Intended use |
| --- | --- |
| `itamaros-logo.png` | Full master wordmark for About, documentation and website |
| `itamaros-mark-512.png` | Square emblem for website UI, native Linux app and desktop app |
| `itamaros-icon-192.png` | Android/PWA home screen icon |
| `itamaros-maskable-512.png` | Mask-safe Android/TV PWA icon with dark blue background |
| `itamaros-apple-touch-180.png` | iPhone and iPad home-screen shortcut |
| `itamaros-favicon-32.png` | Browser tab icon |
| `itamaros-icon.ico` | Windows multi-size app/installer icon, including 16/32/48/64/128/256 pixels |

The repo also includes:
- `assets/itamaros-icon.svg`: SVG compatibility wrapper for the same raster emblem.
- `desktop/assets/...`: Windows, Linux and Mac **offline** Electron build logo inputs.
- `desktop-app/assets/...`: Windows **online** Electron build logo inputs.
- `native/config/includes.chroot/usr/share/pixmaps/itamaros.png`: native Linux icon.
- `native/config/includes.chroot/usr/share/icons/hicolor/512x512/apps/itamaros.png`: native Linux system application icon.

These are official **project** assets; they do not imply completed operating system support on iPhone or TV. Those devices use the responsive web demo or home-screen shortcut only.

## Applying logo changes

1. Replace the brand master image and regenerate PNG variants and ICO from that exact source, preserving reasonable padding for small app icons.
2. Update `manifest.webmanifest`, website favicon/Apple touch references, Electron `build.*.icon`, native GTK/Tk photo icons and service-worker caches as needed.
3. Test in browsers and rebuild Windows/Mac/Linux desktop packages. Previously released EXE/DMG/AppImage binaries **do not change just because the website or GitHub source changes**.
4. Only publish an OS ISO icon/splash after the image has actually been built and verified in a VM.


For a smoother display of the full wordmark in the About screen, `itamaros-logo.webp` is a high-quality transparent 768px copy of the original. The `.png` remains a broad-compatibility and social-preview fallback.

## Native Apple and Android logos

New device-specific asset catalogs are in [Apple](../../native-apps/apple/) (iPhone/iPad, Apple TV, Mac, Apple Watch, Vision Pro), plus Android/Android TV resources in [Android](../../native-apps/android/). Apple iOS icons use a 1024px master export; tvOS has a wide icon and top-shelf art; Android TV has a wide 320×180 banner. Colors, identity and mark remain consistent across devices.
