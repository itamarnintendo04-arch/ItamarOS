# ItamarOS email and administrator onboarding

## Signup and transactional email

**Registration** requires a username (3–24 allowed characters), an email address and a password (8+ characters). A photo and phone are optional. Phone metadata is **not verified** and must never be used for signing in, password reset or assigning privileges.

For email delivery, use a transactional provider such as Resend. Their SMTP integration currently specifies:

- SMTP host: `smtp.resend.com`
- Port: `465` with TLS/SSL
- Username: `resend`
- Password: the server-side **API key** (never store in public GitHub files or the app)
- Sender address: an address on a sender domain whose DNS records you have verified

Set these in your private authentication server email/SMTP settings. Configure your account provider's **Site URL** and allowlist both `https://itamaros-web-emulator.onrender.com/connect.html` and `https://itamaros-web-emulator.onrender.com/accept-invite.html` as redirect URLs. Enable email confirmation. Test with an inbox you control before opening public registration. The Resend limits and policies can change; check their official pricing and setup docs.

## Administrator console and manual invitations

Source: `admin.html`, `apps/admin.js`, `accept-invite.html`, `apps/accept-invite.js` and `messaging/functions/itamar-admin-console/index.ts`.

The server-side function is deployed under `itamar-admin-console` and is configured to validate a signed-in user's identity. It accepts only a **verified account** bearing `app_metadata.itamaros_admin === true`. This role may be provisioned **only by an authorized server operator after verifying the account owner**, through a private admin API or management console; client users cannot grant it to themselves. Signing up using a named email **does not automatically create an administrator** and a fixed four-digit code such as `0123` is **not** a safe administrator credential.

Once correctly provisioned and signed in, the operator can open `/admin.html` to view a limited user directory and generate a private, expiring invitation URL. The invitation is produced without emailing anyone. The operator uses **Copy invitation link** and sends it manually and privately to the intended email address. That person visits the one-time link at `/accept-invite.html` and chooses their own password. Never post the link in a public chat or record the token in logs.

The admin view intentionally **does not expose private chats or arbitrary personal data**, delete user accounts or assign admin roles to new users. It is not a bypass for authentication. Full audit trails, invitation rate limits and manual-device tests should be completed before treating it as a production administration tool.

At the last query, the requested initial administrator email was **not yet present** in the active application user directory. Do not assume it is onboarded or grant this role automatically.

## Notes

- The GitHub branch contains the web UI; it must be merged and deployed for the public URLs above to serve it.
- Email SMTP is not configured by adding these files alone.
- All invitation and reset links are security credentials: short-lived, private and recipient-controlled.

## Verified accounts, user directory, official messages and QR profiles (2026-11-02)

- The project operator verified the account `itamarnintendo04@gmail.com` already existed and had confirmed email. Its account was explicitly granted server-only `app_metadata.itamaros_admin = true`, with no password or login bypass. A green first-party verification seal was added to that exact user ID in `itamar_profile_badges`.
- Web administrator pages `admin.html` + `apps/admin.js` show paged accounts including display names, profile pictures, unique UUID user IDs and emails. Email is **admin-only**, never shown on the public profile page; no password is queried or returned. The backend checks the current signed-in user's *verified identity and server-stored admin role* for every administration action.
- Administrators can award/revoke only **blue** badges to email-confirmed non-admin users; they cannot create another green badge or alter admin permissions through this interface. Both green and blue badges use a distinctive scalloped verified-check seal rather than an Instagram logo.
- The admin may compose a targeted **in-app** official message. The server writes it with sender and recipient IDs, rate-limits to 50/hour, and writes an audit record. Recipients can read only their own notices on the ItamarConnect Updates page; no email is sent for these messages. Authorization and per-user storage access are enforced by database policies.
- Every account has a stable UUID and public profile route `/profile.html?id=<uuid>`. Search requires an exact ID. `profile.html` shows name, username, avatar, about, badge and an on-device QR to that public profile URL, **not email or phone**. A user without a finished profile shows a generic name until profile creation. Android and Apple native account screens also show their own ID and QR link/QR.
- Backend function `itamar-public-profile` returns only allowed public fields and `itamar-admin-console` controls admin functions. Both have been deployed to the project; web pages and native app UIs are still in unmerged GitHub pull requests until tested and published.
- In production, test role revocation, expiring links, inbox RLS isolation, lack of public email exposure, image URL validity and email-sender domain before publishing.
