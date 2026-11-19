# ItamarOS OAuth Beta — operator setup

The beta application portal is at `/developers/index.html`.
The user consent screen is at `/oauth/consent/index.html`.

## Supabase project

This integration belongs to the **ItamarOS** Supabase project (not ItamarOS App Studio):
`slqjkysinhfkqjoigfuz`.

Already installed:
- `public.itamar_oauth_beta_requests`, with RLS enabled and no client grants
- `itamar-oauth-beta` Edge Function with explicit verified-user and admin checks
- Developer application form and approvals UI
- OAuth consent UI

## Required operator steps

1. In **Supabase > Authentication > OAuth Server**, **enable OAuth 2.1 Server**.
2. Set authorization URL path to `/oauth/consent/index.html`. Supabase combines this with the Auth **Site URL**.
3. Ensure Auth **Site URL** points to `https://itamaros-web-emulator.onrender.com` and the host actually serves `/oauth/consent/index.html`. Review existing sign-in routes before changing the global Site URL.
4. In **Authentication > URL Configuration**, allow `https://itamaros-web-emulator.onrender.com/developers/**` and `https://itamaros-web-emulator.onrender.com/oauth/consent/**` for email magic-link redirects.
5. Configure production SMTP under **Authentication > SMTP Settings**. The default email service has restrictions and is not suitable for public beta notifications. Test that a confirmed ItamarOS user receives email magic links.
6. If requesting OIDC `openid` scopes, configure **asymmetric signing keys** (RS256/ES256) as specified in Supabase OAuth Server docs.
7. Make sure the ItamarOS administrator account has server-controlled `auth.users.raw_app_meta_data.itamaros_admin=true`. Never grant this through user metadata or public forms.
8. Test the complete flow with a non-admin verified account: request → admin approve → automatic email → authenticated claim → one-time client credentials → external app OAuth consent.

## Client registration lifecycle

1. A verified ItamarOS user signs in by email magic link and submits application information.
2. The Edge Function stores the authenticated email address from Supabase Auth, not user-controlled email input.
3. A trusted administrator approves or rejects it.
4. On approval, the function sends an email magic link via Supabase Auth to the verified user's email.
5. The developer opens the link and signs in to the portal. Clicking **Reveal client credentials** registers the OAuth client through the server-side Supabase OAuth Admin API.
6. Client ID and, for confidential clients only, the Client Secret are shown once. **The client secret is not stored in our application table, URLs, browser storage, or email.**
7. Public clients get **no secret**; they must use PKCE. Confidential apps store secrets on their server only.
8. If credentials are lost, an administrator must rotate the secret using **Authentication > OAuth Apps**.

An approved request may still require the developer to claim credentials. If SMTP is missing or limits are reached, the approval remains recorded but email delivery is not guaranteed. The admin UI reports email delivery failure.

## Security notes

Do **not** enable unauthenticated dynamic OAuth client registration in production: it bypasses the beta approval process.
Do **not** put a service-role/secret key in GitHub or browser JavaScript. The Edge Function uses server-side runtime-provided credentials.
No app passwords are requested by the developer form. All user-supplied URLs are validated on the server.
Data sent from external OAuth applications is subject to the user consent screen.
Frontend and backend currently have no infrastructure-level bot protection; add CAPTCHA, abuse monitoring, and rate-limiting before broadly opening registration.

### References

- https://supabase.com/docs/guides/auth/oauth-server/getting-started
- https://supabase.com/docs/guides/auth/oauth-server/oauth-flows
- https://supabase.com/docs/guides/auth/custom-oauth-providers
