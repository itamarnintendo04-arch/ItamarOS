# ItamarOS Authenticator

Native iOS authenticator for ItamarOS (SwiftUI, iOS 16+).

**Current implementation (v1.3):**
- Six-digit TOTP/HOTP verification codes (SHA-1, SHA-256, SHA-512)
- Import a standard \`otpauth://\` QR code or enter a Base32 setup key
- Store secrets in iOS Keychain, not UserDefaults
- Refresh codes automatically and show expiry
- Link a verified ItamarOS account by email OTP to receive sign-in approvals
- Approve/deny requests with device authentication and a P-256 device-bound signature
- Optional APNs registration (requires Apple Developer provisioning)
- Email sign-in fallback and optional companion app recommendation on first launch (web components)

**Build**: GitHub Actions → **Build ItamarOS Authenticator IPA** → download unsigned IPA artifact. The unsigned IPA **requires signing** before installation on a physical iPhone. A Mac with Xcode and a signing certificate is needed for a fully installable release.

**Important:** The remote approval service is *not active* until the Supabase migration and Edge Function in the separate source package are deployed, thoroughly tested and integrated with the host apps. Do not substitute an approval for a real authenticated session without server-side verification. Push while closed requires valid APNs configuration. This repository currently builds the native app. See [docs/AUTO_SIGN_IN.md](docs/AUTO_SIGN_IN.md).

**All UI strings are in English.**


## Email sign-in robustness update (2026-11-21)

The iPhone Authenticator now keeps the verified Supabase email OTP session in Keychain even when the optional device-approval Edge Function is not deployed. The UI shows an explicit warning and a **Retry approval setup** action instead of claiming email sign-in failed. A successful later approval service sync clears the unavailable state.

**Deployment required:** The ItamarOS Supabase project currently does not contain the `itamar-authenticator` Edge Function or approval tables. Accordingly device approval, automatic cross-service sign-in and background push remain unavailable until the secure broker and database policies are deployed and tested. The six-digit email code also requires the project email template to be configured for OTP, rather than Magic Link only.

No private Apple signing credentials are included, and this app does not automatically sign or install IPA files.
