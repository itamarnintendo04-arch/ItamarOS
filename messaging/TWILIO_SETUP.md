# ItamarOS registration — updated requirements (2026-11-02)

**Current intended flow:** Username, email and password are REQUIRED. Phone and profile picture are OPTIONAL. Signing up via Supabase Auth `signUp({email,password,options:{data:{preferred_username,...},emailRedirectTo}})` triggers an email confirmation when email confirmation is enabled. It is not an SMS flow. Email link landing URL must be on Supabase's auth redirect allowlist and the email provider/SMTP must actually work. Returning users sign in with email and password. Cloud Climb supports QR approval using a device already signed in. Optional phone contact is kept in user metadata as **unverified** and must not be used for login, account recovery, identity checks, or public profile display. Photos are optional (default avatar) and can be uploaded after confirming email.

**Phone number autofill:** Android's Play Services Phone Number Hint suggests possible numbers only after a deliberate user action. An iOS app cannot reliably read the SIM phone number, and a web browser cannot auto-read it either. Users can always enter the optional contact number manually.

**Migration notes:** Old Twilio SMS/OTP notes, password-optional signup, and required phone verification are deprecated. Existing phone-only accounts may need a separate verified email-link upgrade before they can use email/password. We have not automatically migrated or deleted any existing accounts. Configure Supabase Auth email confirmation and SMTP in the Dashboard and test with a real inbox. Do not store secrets in browsers or mobile binaries.

# ItamarConnect — Supabase + Twilio SMS setup

**Development integration; not yet active until you configure your own new Supabase project.** Do not restore or reuse the old deleted Supabase project.

## 1. Create/configure your Supabase project

Use a dedicated **ItamarOS** Supabase project under an organization you control. Review project creation costs first. The app code is in the separate GitHub repository `itamarnintendo04-arch/ItamarOS`.

Apply the message database migrations **in order**, only after reviewing them in a staging database and testing RLS:
`supabase/migration.sql`, `supabase/extended-features.sql`, `supabase/message-experience.sql`, `supabase/conversation-tools.sql`.

For production: check security/performance advisors, privacy rules, abuse reporting/moderation, rate limits, logging, data retention, and cross-device integration. No live database was modified by creating these source files.

## 2. Enable Twilio SMS authentication

Supabase Dashboard → **Authentication → Providers → Phone**:

1. Enable phone login and select **Twilio** (Programmable Messaging), **not Twilio Verify**, as the SMS provider.
2. Configure an authorized Twilio sender and **Messaging Service SID**, then enter the Twilio Account SID, Auth Token and Messaging Service SID **only in the private Supabase Dashboard fields**. Do not paste secrets into `public-config.js`, JavaScript, Kotlin, Swift, README examples, public GitHub commits or client builds.
3. Enable rate limits and CAPTCHA where supported, restrict allowed destination countries and add spending alerts. **Twilio Programmable Messaging still charges for SMS messages** (and possibly sender numbers and carrier fees); avoiding Verify does not make SMS free.
4. Test with approved test numbers and a staging project before going live. Trial Twilio accounts have destination restrictions.

The clients use **Supabase Auth**:
- Request: `auth.signInWithOtp({phone:'+972…'})` on the web, or `POST /auth/v1/otp` on native clients.
- Verification: `auth.verifyOtp({phone,token,type:'sms'})` on the web, or `POST /auth/v1/verify` on native clients.
- The server signs in the user **only after** verifying their OTP. Code requests by themselves are **not a login**.
- No custom Twilio SMS-sending service or custom OTP database is needed. Supabase creates and validates the one-time code while Twilio Programmable Messaging delivers the SMS.
- The ItamarConnect **web** Create account form requires three fields marked **\***: a unique @username (3–24 permitted characters), an email address, and an international phone number. Users also choose an uploaded JPG/PNG/WebP profile image (max 3 MB) or a default avatar. Password remains optional (minimum 8 characters). Phone registration first verifies an SMS OTP; then `auth.updateUser({email})` attaches the required email to that **same** Auth user and sends a confirmation email. The email is not usable as a verified sign-in identity until the user confirms it. Supabase email template delivery and redirect allowlists must be configured.
- Existing users can sign in by phone OTP or by phone + password if they chose one. Password entry skips a new SMS request. The native iOS/Android clients still require their own UX updates to match this web signup screen. These changes remain source-only until a backend is configured and tested.
- Uploaded profile images are public; do not require a real face or government-identifying photo.

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

## Required registration fields and manual sign-in (web)

New ItamarOS web registrations require **username \***, **email \*** and **phone number \***. The username is public; email and phone are private Auth identities. An uploaded picture or default avatar is selected; passwords are optional. Account email confirmation must be completed via the confirmation mail. Existing accounts are not automatically removed, and the native registration screens still need to be aligned with these requirements before a production release.

Manual login supports the existing user's **email or phone plus password**, **phone SMS OTP**, or **email Magic Link/OTP** (depending on Supabase Email template settings). For email links, the web client now allows auth tokens in redirect URLs; allowlist the exact deployed web URL under Supabase Authentication → URL Configuration and verify that your public browser host redirects correctly. `shouldCreateUser:false` prevents login requests silently making new accounts.

Cloud Climb's separate native apps also support QR approval from an already signed-in ItamarOS installation, or manual sign-in using the same existing account. QR login is **not** a substitute for creating or verifying an ItamarOS account. No live cross-device test is implied by source updates.
