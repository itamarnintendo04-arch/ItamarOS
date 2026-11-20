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
