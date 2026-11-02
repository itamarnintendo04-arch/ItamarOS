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
