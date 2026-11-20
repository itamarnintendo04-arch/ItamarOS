# Auto sign-in implementation contract — v1.2

## Required behavior
1. First link a device with the existing user's six-digit **email** OTP (one time).
2. Each ItamarOS service defaults to **Sign in with ItamarOS Authenticator**.
3. Request is delivered to the paired device; show the service name + matching number.
4. User approves or denies. An approval requires Face ID/device passcode and a device-bound P-256 signature.
5. The service exchanges the single-use approval for an authenticated session.
6. A small **Sign in with email instead** link sends a six-digit OTP.
7. On the **first launch** of any ItamarOS application, offer **Install / Not Now** when a real installation URL exists.

## Server/API
The full source package contains:
- `supabase/migrations/20261119180000_itamar_authenticator_approvals.sql`
- `supabase/functions/itamar-authenticator/index.ts`
- `web/sign-in.html` and `web/sign-in.js`
- `web/companion-prompt.js`
- iOS SwiftUI approval/notification components

The broker actions are `enroll` (authenticated), `start` (unauthenticated), `pending` (authenticated), `decide` (authenticated + signed) and `poll` (possesses requester token).
Requests expire after 180 seconds and can be redeemed once. The user's private signing key stays in the iOS Keychain.

## Needed for a real push
Apple Developer Push Notifications entitlement, a signed app, APNs device registration, server-only `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_KEY_P8`, `APNS_BUNDLE_ID` and an APNs sandbox/production match.

Without these, requests can be fetched while the app is open; **background pushes won't work**. The app cannot silently install another app or insert a third-party prompt into iOS's installation screen. Show the optional recommendation on first launch.

The ItamarOS Supabase project and ItamarOS App Studio project are separate. Services on another auth project must integrate via the verified ItamarOS OAuth identity system or another securely designed token exchange.

## Rollout
Do **not** replace the existing login page with this flow until the backend, APNs, fallback email OTP and signed IPA have been tested on real accounts/devices. The ChatGPT-generated v1.2 ZIP supplies the source, but the repo and production project are not yet deployed end-to-end.
