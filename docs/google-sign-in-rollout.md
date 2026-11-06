# Google sign-in for ItamarOS

Status: configuration and implementation checklist; NOT enabled in released apps.

## Account identity
Google must be added as an OAuth provider to the existing ItamarOS authentication backend. Do not create a separate Google-only user database. A Google login should resolve to the same backend user ID and the same username/profile, game progress, and saved data.

## Provider configuration
1. Create Google OAuth consent screen and OAuth client in Google Cloud Console.
2. Add the backend provider callback URI to Google OAuth authorized redirect URIs (from the backend Auth provider settings).
3. Enable the Google provider in the backend Auth configuration and set client ID and secret there, never in mobile binaries or git.
4. Allow each platform's exact callback URL in the backend Auth redirect allow-list.
5. Test first-time login, returning login, existing email/password account linking, cancellation, and logout. Never auto-merge accounts solely because email addresses match.

## Platform implementation requirements
- iOS/iPadOS and standalone Cloud Climb: use ASWebAuthenticationSession with OAuth authorization-code + PKCE. Validate callback state and exchange code for a backend session; persist via the existing Keychain-backed ItamarCloudService.
- macOS: ASWebAuthenticationSession + PKCE, Keychain session storage.
- Android and Android TV: system browser / Custom Tabs with authorization-code + PKCE, Android App Links or verified deep link, secure session storage.
- Windows: system browser + PKCE and loopback or registered callback, secure Windows credential storage.
- Web: backend OAuth redirect flow with PKCE, secure cookie/session handling.
- tvOS/watchOS: device authorization or QR pairing to an authenticated companion device, rather than unsupported embedded Google web login.

## Release gate
Do not display an active Google sign-in button until the platform callback, provider configuration, and successful end-to-end authentication are verified. No app can obtain a valid Google login merely by showing a button.
