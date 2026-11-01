# ItamarConnect — Supabase + Twilio SMS setup

**Development integration; not yet active until you configure your own new Supabase project.** Do not restore or reuse the old deleted Supabase project.

## 1. Create/configure your Supabase project

Use a dedicated **ItamarOS** Supabase project under an organization you control. Review project creation costs first. The app code is in the separate GitHub repository `itamarnintendo04-arch/ItamarOS`.

Apply the message database migrations **in order**, only after reviewing them in a staging database and testing RLS:
`supabase/migration.sql`, `supabase/extended-features.sql`, `supabase/message-experience.sql`, `supabase/conversation-tools.sql`.

For production: check security/performance advisors, privacy rules, abuse reporting/moderation, rate limits, logging, data retention, and cross-device integration. No live database was modified by creating these source files.

## 2. Enable Twilio SMS authentication

Supabase Dashboard → **Authentication → Providers → Phone**:

1. Enable phone login and choose **Twilio** or **Twilio Verify** as the SMS provider.
2. Enter the requested Twilio Account SID, Twilio Auth Token and messaging/verification service identifiers **only in the private Dashboard fields**. These values must never be in `public-config.js`, JavaScript, Kotlin, Swift, README examples, public GitHub commits or client builds.
3. Enable rate limits and CAPTCHA where supported. Twilio/Supabase SMS may incur charges. Only deliver codes to numbers your users control and take account of applicable SMS regulations.
4. Test with an approved testing number and a non-production project before going live.

The clients use **Supabase Auth**:
- Request: `auth.signInWithOtp({phone:'+972…'})` on the web, or `POST /auth/v1/otp` on native clients.
- Verification: `auth.verifyOtp({phone,token,type:'sms'})` on the web, or `POST /auth/v1/verify` on native clients.
- The server signs in the user **only after** verifying their OTP. Code requests by themselves are **not a login**.
- No custom Twilio SMS-sending service is needed. The credentials are stored by Supabase as the SMS provider.

Official references: [Supabase Phone Login](https://supabase.com/docs/guides/auth/phone-login), [JavaScript OTP](https://supabase.com/docs/reference/javascript/auth-signinwithotp).

## 3. Connect public clients, without secret keys

Only **public** values belong in client builds:
- `messaging/public-config.js`: `url` and `publishableKey` from the new project's API settings.
- iPhone/iPad: `ITAMAR_SUPABASE_URL` and `ITAMAR_SUPABASE_PUBLISHABLE_KEY` app build configuration.
- Android: Gradle properties of the same names (public, not service_role).

`service_role`, project database passwords, Twilio Auth Token and Apple signing keys **must stay on server/provider systems**, never in client files.

## 4. Per-device synchronization privacy

Each client has a local setting: **Sync chats and contacts on this device** (on by default, user can turn it off). Turning it off stops this device fetching cloud conversations/contacts. It does not delete content already delivered to other people, stored on the server or visible on other signed-in devices. This is distinct from the optional *public discoverability by verified phone number*, which is off unless the user opts in.

The web browser stores the sync switch under `itamaros-connect-device-sync` in its own local storage. Android stores `connectSync` in its app preferences. iOS/iPadOS uses `itamaros.connect.syncEnabled`. These switches are deliberately **per-device**, not copied to other devices.

Phone numbers are used only for verification or an individually authorized lookup. Do not automatically upload a device's contacts. Full end-to-end encrypted messaging, reliable background push, voice/video calling and a verified active service are not provided by these changes.

## 5. Validate and release

Run GitHub Actions [ItamarOS smoke tests](https://github.com/itamarnintendo04-arch/ItamarOS/actions/workflows/validate.yml), [Android build](https://github.com/itamarnintendo04-arch/ItamarOS/actions/workflows/native-android.yml), and [unsigned iOS IPA build](https://github.com/itamarnintendo04-arch/ItamarOS/actions/workflows/ios-unsigned-ipa.yml). Test with different accounts, devices, blocked users, phone verification, local sync-off, and network errors before release.
