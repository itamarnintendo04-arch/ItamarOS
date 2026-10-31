# ItamarOS Connect — optional cross-device messaging (developer preview)

The iOS 1.6.2 source includes an **opt-in** native, authenticated messaging client. Without the Supabase configuration it keeps the current offline, on-device messages preview, not an imaginary network.

## Setup checklist

1. Create a Supabase project and turn on **Authentication → Email**. Require email confirmation, configure a real email provider for production, and enable rate limiting/CAPTCHA as needed.
2. Run [migration.sql](supabase/migration.sql) from Supabase SQL Editor. It creates Row Level Security (RLS) policies for signed-in profiles, chats, channels, message read/write access, block relationships and time-limited parent invites.
3. Copy your **Project URL** and **public publishable/anon key** (NOT `service_role`) into `native-apps/apple/project.yml` under `ITAMAR_SUPABASE_URL` and `ITAMAR_SUPABASE_PUBLISHABLE_KEY` within the iOS `info.properties` block. Rebuild the unsigned/signed iOS app after configuration.
4. Place the same public values into [public-config.js](public-config.js), hosted with the ItamarOS website, so [parent.html](../parent.html) can accept the invitation from a browser. The redirect URL (`https://itamaros-web-emulator.onrender.com/parent.html`) must be allowlisted in Supabase Auth URL configuration.
5. Test with **separate** test accounts on two real devices; confirm isolation, no unauthorized message access, muted activity filtering, parent invite expiry and single-use redemption.

Do **not** place Supabase service role keys, Apple certificate passwords, Apple account passwords, or any API secret in this repository or a public web bundle.

## What the connected iPhone app does

- Email/password sign-up and sign-in using Supabase Auth; save access/refresh tokens in the iPhone Keychain (device only)
- Profile display name, unique public @username and short About
- Start a chat with another @username; discover/follow public channels (only channel owner can publish)
- Messages and membership stored remotely with RLS, not in local browser state
- Chats, channels, and Updates activity feed; mute a room to exclude its posts from Updates
- Foreground polling for message activity and explicit permission request for notifications
- Optional iOS Contacts permission: only names are read *on the phone*, no contacts are uploaded or matched by email/phone
- Parent QR: one-time 15-minute invite redeemed using a different **verified-email** account, from the native app or the browser page; no access to private messages or control permissions is granted

## Limits before a public launch

- **Background remote push notifications do not work yet.** APNs device token registration, a trusted server/Edge Function for notifications, and Apple push entitlement/signing are still required. The in-app Updates feed works while the app is active.
- **No end-to-end encryption**, no calls, media attachments, groups, abuse reporting or automated content moderation. Admins of the connected Supabase project may access database records as platform operators. Do not describe this as secure like WhatsApp or launch it as a public service for minors before proper safeguards, block/report tools, abuse handling, retention policies and privacy review are complete.
- QR links are bearer invitations: treat as temporary secrets. Inviting the parent requires the user to be signed in; redeeming requires parent account authentication with a confirmed email. This proves account control **not** legal guardianship.
- The website tries the custom `itamaros://parent?invite=...` link on an Apple device; browsers may block automatic app launching. A reliable OS-managed Universal Link would require a correctly signed Apple app, Team ID, Associated Domains entitlement, and `apple-app-site-association` on the live HTTPS host. The browser form remains as fallback.
- There is no silent iOS IPA auto-update. The app checks [native-apps.json](../updates/native-apps.json) and may show a published *signed* version; distribution remains through supported signed installation methods.

The iOS build workflow uploads an **unsigned IPA artifact**, which must be appropriately signed for an authorized device before installation. The source build passing CI is not a substitute for testing the backend and iPhone app together.
