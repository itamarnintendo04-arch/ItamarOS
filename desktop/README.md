# ItamarOS Demo for desktop (not the native operating system)

Electron/Chromium wrapper around the **browser emulator**, bundled with local assets. This is an ordinary desktop application — it does not flash drives, install an OS, or require admin privileges.

## Build locally

Requires Node.js 22+.

```bash
cd desktop
npm install
npm start
```

Build on Windows with `npm run build:win` for a portable `.exe` and on Linux with `npm run build:linux` for an AppImage. Result is in `desktop/build`. Generated binaries are **not** code-signed. Do not disable OS security warnings blindly: only use artifacts you trust and verify.

The package includes 16 games, the Itamio video launcher, the demo player and update checks. A demo update only opens verified download listings; it never silently replaces its executable.

The Electron process binds an ephemeral **localhost-only** HTTP port, serves an allowlisted set of bundled files, disables renderer Node access, and opens external HTTPS links in the system browser.

## Updates

The demo checks GitHub metadata while the app runs. A new version requires downloading an actually published demo release after verification. It does not automatically install executable packages or assume a remote website reload changes the local app.

## CI build

`.github/workflows/desktop-demo.yml` builds installable test artifacts on GitHub Actions. Test artifacts are not automatically advertised as stable Releases. Publish a GitHub Release only after Windows/Linux smoke testing, a human review and verifying checksums.
