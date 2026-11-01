# ItamaRos Hub → ItamarOS Connect (integration reserved, NOT ENABLED)

The user requested that the **Sign in with ItamaRos Hub** button be added **only after they explicitly say to enable it**. Do not silently enable the button, run a fake login, or infer a production Hub URL.

## Prepared callback

When Hub supports OAuth 2.0 / OpenID Connect and is ready to be integrated, register this precise HTTPS redirect URI with Hub:

**`https://itamaros-web-emulator.onrender.com/hub/callback.html`**

The existing [callback page](callback.html) and [public configuration](config.js) are deliberately disabled by default. The callback checks the saved request `state` and PKCE verifier, and only sends the authorization code to a **same-origin verified server-side exchange** at `/api/hub/exchange`. This server endpoint does **not exist yet**. A random `?email=` or `?name=` URL value is not authentication.

### Required protocol before activation

1. Hub publishes a verifiable HTTPS OIDC issuer (discovery and signed JWKS), an authorization endpoint, token endpoint, documented scopes, and its public client ID for ItamarOS.
2. Use Authorization Code **with S256 PKCE**, cryptographic `state` + nonce, exact redirect URI, and the **system browser** for iOS/Android native login (not an embedded login WebView). Embedded WebView is reserved for the independent IPA signing workspace.
3. The server exchanges the code, validates issuer/signature, audience, nonce, token expiration, consent and authorization, maps a stable Hub subject ID to an ItamarOS user, and returns a **single-use, short-lived, scoped handoff ticket**. Exchange secrets and provider tokens remain server-side.
4. The browser may open `itamaros://hub-auth?ticket=<opaque one-use ticket>`; the native app must redeem it against an authenticated HTTPS endpoint before storing an account session. **Simply receiving this URL never signs a user in.**
5. Import only claims requested and approved by the user — stable subject ID, display name, chosen username, profile picture and confirmed email as available. Do **not** automatically import private contacts, phone, home address, passwords or arbitrary profile fields.
6. For browser emulator, a same-origin secure session with HttpOnly cookies is preferred, with CSRF protections. For installed apps, store scoped sessions in the platform secure storage and provide sign-out/revocation.
7. Add a clear account-linking confirmation before merging an existing ItamarConnect account with an external Hub identity. Profile overwrites and account linking must never be automatic on a same-email guess.

### Client state

- iPhone: recognizes the future `itamaros://hub-auth` return route but **shows a disabled-integration notice**; no profile is imported and no ticket is redeemed.
- Android: reserves the same return route, also with **no authorization or account linking**.
- Browser, desktop emulator and prototype Linux OS: ItamarConnect is accessible through `/connect.html`; the future Hub button is not shown.
- The separate [IPA signing workspace](../native-apps/apple/Shared/EmbeddedIPASignerView.swift) already uses `WKWebView`. It is **not** a login browser and should never collect Apple account passwords.

### Activation checklist — ONLY when requested

Hub issuer URL, client registration/redirect URI, consented claims, server-side ticket exchange and a tested HTTPS deployment are prerequisites. Enable the Hub button only after these are configured and verified; update the app's ticket redemption path, add end-to-end tests and audit consent/privacy first.

Do not claim that any of these preparatory files authenticate users. The existing Connect cloud feature also needs its dedicated Supabase migrations, configuration, staging tests and security review before cross-device chat is live.
