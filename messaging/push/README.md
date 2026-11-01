# ItamarOS native chat push (APNs + Firebase)

Status: backend queue and Edge Function are deployed, and token-registration code exists. Remote notifications WILL NOT deliver until the owner supplies valid provider credentials, configures a trusted scheduler, signs iOS with Push entitlement, and completes a device-to-device test.

## Components
- SQL: messaging/supabase/push-foundation.sql (opt-in push-device registry, private outbox, generic notifications, mute/block checks)
- Supabase Edge Function: messaging/push/dispatch.ts, deployed as itamar-push-dispatch.
- iOS: ItamarAPNsRegistration.swift, ItamarCloudService.swift, and the account's notification settings.
- Android: ItamarPushFirebaseService.kt and Connect notification controls.

## Apple configuration (keep secrets outside GitHub)
1. Use an Apple Developer app identifier matching org.itamaros.mobile and enable Push Notifications.
2. Sign the app with a matching provisioning profile carrying the aps-environment entitlement. An unsigned IPA alone cannot receive production pushes.
3. Store APNS_TEAM_ID, APNS_KEY_ID, APNS_PRIVATE_KEY_P8, APNS_BUNDLE_ID and APNS_ENVIRONMENT as Supabase Edge Function secrets.
4. APNS_ENVIRONMENT is sandbox for a development app and production for a distribution app.

## Android configuration
1. Create a Firebase project with Android package org.itamaros.nativeapp.
2. Provide ITAMAR_FIREBASE_APP_ID, ITAMAR_FIREBASE_API_KEY, ITAMAR_FIREBASE_SENDER_ID and ITAMAR_FIREBASE_PROJECT_ID as public build-time Gradle properties.
3. Store FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY only as Supabase Edge Function secrets. The server needs permission for FCM HTTP v1.
4. Install a properly configured APK, grant notifications permission and choose Enable chat Push in Connect.

## Dispatching
Create a strong random ITAMAR_PUSH_DISPATCH_SECRET as a Supabase Edge secret. Set up a server-side scheduler that POSTs to /functions/v1/itamar-push-dispatch with x-itamar-dispatch-secret. Never put the secret in GitHub or an app. A server-only schedule or securely authenticated webhook is required; it has NOT been connected yet. Supabase service credentials must also be available as server-only environment variables.

Use the provider's delivery logs for real-device end-to-end verification. The current dispatcher is a prototype; rate limits, retries and revocation should be hardened before a public release.

Push content is deliberately generic and never exposes private messages or room codes on the lock screen.

References:
- https://supabase.com/docs/guides/functions/examples/push-notifications
- https://firebase.google.com/docs/cloud-messaging
- https://developer.apple.com/documentation/usernotifications
