# ItamarOS — Codebase import/build brief

**Project name:** ItamarOS

**Existing source of truth:** https://github.com/itamarnintendo04-arch/ItamarOS

## Paste this into your Codebase workspace

Build a responsive ItamarOS project called **ItamarOS**. Start by reviewing the existing GitHub source instead of creating an unrelated operating system. Use the official project logo and original app icons. ItamarOS has: a browser OS emulator, installable Windows/Linux/Mac emulator, a prototype native Debian-based PC OS source recipe, native iPhone/iPad and Android/Android TV application code, offline games, a media player, and an ItamarConnect messaging application.

Requirements:
- Desktop-style taskbar, Start/All apps launcher with search and alphabetical sections; include all built-in ItamarOS apps. On the packaged Windows Electron desktop edition only, show installed Windows Start Menu shortcuts through a restricted read-only native bridge; never invent programs or list private files.
- Responsive desktop, tablet and mobile layouts. On iOS use system-native SwiftUI tabs, Android native Jetpack Compose. The prototype Linux OS has a launcher for the first-party Connect web application.
- **ItamarConnect**: account profiles, optional profile images/group descriptions, username/contact QR, private chats, groups, channels, updates, message delivery/read receipts, media attachments, reactions, polls and message editing. Do not claim WhatsApp feature parity or E2EE; do not simulate delivered messages without a verified backend.
- **SMS login**: Supabase Auth with provider Twilio/Twilio Verify configured in the Supabase dashboard. The client calls OTP + verify endpoints using **public Supabase keys only**. Never include Twilio Auth Token or Supabase service_role in client code.
- **Device-specific sync**: local switch under Settings for loading chats and contacts on each device. If disabled, do not fetch cloud messages. Do not erase already delivered messages, and do not upload device address books without explicit consent.
- **ItamaRos Hub sign-in**: do NOT enable until explicitly instructed. A reserved callback exists at `/hub/callback.html`; it must not trust URL claims, access tokens or email alone for identity. The eventual server-side OAuth/OIDC Authorization Code + PKCE flow is pending.
- **IPA signing**: an opt-in native iOS WKWebView opens the existing first-party signer, processes only user-chosen files, and uses the user's authorized Apple developer signing assets. Never request Apple ID passwords; do not claim WebView signs or installs without actual certificates.
- Keep older builds/links in README. Never delete existing projects/repositories without explicit authorization. Preserve all existing work and create reviewable changes.

Integrate only against a verified, dedicated Supabase database and test the RLS policies with independent users. Avoid marketing an experimental ISO as a verified OS installer.

## Import/use

Open your Codebase workspace, create a project titled **ItamarOS** and provide this brief alongside the GitHub URL. If your Codebase workspace supports repository import, import it rather than re-implementing the whole source. Review the build's diff and preview before deployment. This file does not itself create or synchronize an external Codebase project; account access is required.

See [Codebase quickstart](https://codebase.design/docs/quickstart) for the workspace creation flow. For the active ItamarOS source, see [repository README](../README.md) and [messaging setup](../messaging/README.md).
