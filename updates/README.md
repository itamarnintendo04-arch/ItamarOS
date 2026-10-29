# ItamarOS updates (release channels)

**Development branch:** `updates`. All changes are implemented and tested there first.

**Production branch:** `main`. Merge a reviewed pull request from `updates` into `main` when ready. The Render static service auto-deploys the updated site from `main`.

The browser periodically reads the stable manifest stored in GitHub at:
`https://raw.githubusercontent.com/itamarnintendo04-arch/ItamarOS/main/updates/stable.json`
The deployed copy `/updates/stable.json` is a fallback only.

## Manifest format

- `schemaVersion`: schema version (currently 1).
- `version`: the website release version (semantic version).
- `components`: web bundle parts and versions; `delivery=reload` or `bundled`.
- `installers`: **empty until tested actual native packages exist**. A future installer entry needs platform/device compatibility, release asset hosted under the official GitHub Releases URL, SHA-256 digest, signature and install instructions.

## Browser behavior

The web app checks on load/return to foreground and periodically, and automatically reloads when it is safe to do so. If a player, game, focused input or fullscreen session is active, it offers **Install update** or **Remind me later** instead. A session guard prevents infinite automatic reload loops if the manifest is published before the site deploy finishes. **Settings → Software Updates → Check for updates** triggers a fresh check. A browser update is a reload to the latest deployed web version; on active apps users can postpone it. The browser cannot flash an OS, replace system apps or execute native installers.

For native ItamarOS editions, use the same release manifest as **metadata only**. A separately implemented native updater will need privileged package management, signed artifacts, digest/signature validation, compatibility enforcement, rollback and explicit user consent. No native updater or native installer has been built yet.

## Publishing a new web version

1. Make changes in `updates`.
2. Increase `version` in this manifest and the version constant in `apps/updates.js`, and cache-busting query strings in `index.html`.
3. Run checks on `updates`.
4. Open and merge a PR to `main`.
5. Render auto-deploys main; clients detect the new manifest version after it is published.

Do not claim that placeholder assets are installable. Never publish unverified installer binaries.