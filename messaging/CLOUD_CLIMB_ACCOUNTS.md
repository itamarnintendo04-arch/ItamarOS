# Cloud Climb · ItamarOS account sync and game commands

**Status:** Account preference storage is installed in the ItamarOS Supabase project, and iOS/Android source is updated. Native builds, on-device sync, and SMS delivery are **not yet verified**. The existing game-progress RPCs were already present.

## One account for both apps

- Use **Sign in with ItamarOS** in the separate Cloud Climb app, or use an existing signed-in ItamarOS game screen. The standalone app opens ItamarOS for explicit approval or offers a short-lived QR approval. Do not share passwords, SMS OTPs, or Supabase tokens with the game.
- Levels, earned coins, hearts, boss status, and game-over state use `itamar_cloud_climb_progress` and its `itamar_cloud_climb_state` / `itamar_cloud_climb_save` RPCs.
- World unlocks, collected cubes and earned characters use the existing Cloud Climb reward tables and RPCs.
- **NEW:** Chosen world, equipped character, day/twilight theme, auto-hide controls, and tips use `itamar_climb_preferences` and its `itamar_climb_get_preferences` / `itamar_climb_save_preferences` RPCs.
- Everything above is scoped to the **Supabase Auth user ID** of the ItamarOS account, with RLS on the preferences table. Game preference writes validate world/character unlocks on the server.
- Local save data is stored per authenticated user on iOS/Android. The cloud is authoritative when a saved cloud version exists; offline progress should not silently overwrite a newer cloud save.
- **Play Offline Demo** stays in local storage and **never silently merges or uploads** its save into an online ItamarOS account.

## Game command input

The game command box accepts case-insensitive slash commands on iOS and Android. Commands deliberately do not create coins or unlock stages.

| Command | What it changes / shows |
|---|---|
| `/help`, `/commands` | List available commands |
| `/stats` | Current level, world, hearts, coins, collections |
| `/account` | Current sync/account status |
| `/room` | Current multiplayer room code |
| `/world 1`, `/world 2` etc. | Switch to an **already unlocked** world |
| `/hero list` | List owned hero IDs |
| `/hero starter`, `/hero sky_01` | Equip an **already unlocked** hero |
| `/theme day`, `/theme twilight` | Change background theme |
| `/controls auto`, `/controls show` | Auto-hide touch controls with gamepad or keep them visible (online game) |
| `/tips on`, `/tips off` | Change gameplay tip visibility |
| `/pause`, `/resume` | Stop/resume gameplay |
| `/reset-position` | Return to the start of the stage without changing saved progress |
| `/save` | Request/confirm progress save (auto-save remains enabled) |
| `/sync` | Reload online account progress when signed in |

The standalone iOS **offline** preview offers the relevant subset: `/world`, `/hero`, `/theme`, `/tips`, `/pause`, `/resume`, `/reset-position`, `/stats` and `/save`. It explicitly refuses online `/sync`. Offline mode remains playable without Internet.

## Backend migration

The deployed schema changes are recorded in [`cloud-climb-account-preferences.sql`](supabase/cloud-climb-account-preferences.sql). This file is meant for provisioning **new** environments; do not blindly re-run every migration on production. Auth user IDs are the sole ownership key; the client does not supply another account's ID.

## Authentication cost and phone numbers

- Twilio Programmable Messaging is **paid for actual SMS** after limited trial units; replacing Twilio Verify does not make messages free.
- Existing ItamarOS-app approval and QR pairing can log a player into Cloud Climb without a **new** SMS each time, provided they already have a valid authenticated ItamarOS session.
- Supabase email OTP/magic link is an alternative to SMS (subject to email provider quotas, security configuration and rates). If an account profile still requires a phone number but does not verify it, clearly label it **unverified** — do not pretend it establishes phone ownership.
- Use SMS rate limits, CAPTCHA, regional restrictions, and spending alerts for any phone login.

## Release validation still required

1. Install cloud-enabled iOS and Android builds on different test devices, sign in to the same ItamarOS account, change world/hero/theme, restart, and confirm a later device sees the change.
2. Confirm a second account cannot read/write another user's preferences.
3. Confirm `/hero` and `/world` refuse locked content, and `/save` cannot create arbitrary coins.
4. Check offline demo stays isolated and QR pairing expires securely.
5. Build and test native apps before distributing an APK/IPA. A code change or Actions link does not prove an installable artifact exists.
