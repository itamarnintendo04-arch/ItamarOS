# Google sign-in setup (iOS)

The ItamarOS, ItamarOS Games, Cloud Climb, and Skybound Isles apps now offer a Google OAuth button using ASWebAuthenticationSession and PKCE. **These buttons cannot complete sign-in until Google is enabled in the account provider and the redirect allow-list is configured.**

1. Configure Google as an OAuth provider in the ItamarOS authentication project, including the authorized client credentials and the callback URL shown by the provider.
2. Add these exact native redirects to the authentication provider's redirect allow-list:
   - `itamaros://auth/callback`
   - `itamarosgames://auth/callback`
   - `cloudclimb://auth/callback`
   - `skybound://auth/callback`
3. The iOS apps use PKCE code exchange. Do not embed a Google client secret or server service-role key in an IPA.
4. Build, install and verify on a physical device. Confirm login cancellation, bad redirect, and sign-out behavior.

Authentication state: On a **fresh install** there is no session, so the user sees the login screen. An existing valid session is intentionally restored from the device Keychain, rather than signing out on every launch. To test the first-run experience, explicitly sign out.

Frame rate: The game targets permit higher refresh rates, but no platform setting can guarantee 60 FPS. Smooth Snake uses a 60 Hz update timer; the other games require individual performance testing and, where appropriate, display-linked rendering.
