# Screen Balance implementation status — 2026-11-13

## Backend implemented and applied to ItamarOS
- Live Supabase project: ItamarOS (not ItamarOS App Studio).
- Four tables: balance_links, balance_pairing_requests, balance_tasks, balance_rewards.
- RLS enabled on all four; confirmed by database query.
- Separate authenticated ItamarOS accounts for parent and child.
- Child generates a random one-use QR invitation, expires after ten minutes.
- Parent scans QR while signed in to a separate account; server-side RPC atomically claims the invitation.
- Parent may add, rename, edit and delete child tasks and approve minutes (1–240); the child can read tasks and approvals.
- Child cannot write rewards or tasks through the authenticated API.
- App sync uses Supabase REST with a publishable key and a user's access token; sessions are stored in iOS Keychain.
- Remote updates currently require pressing Sync / re-opening the app; realtime subscription and notifications are not yet implemented.

## Apple Screen Time controls
- FamilyActivityPicker, Family Controls authorization and ManagedSettings shields have been added.
- **Not implemented:** automated temporary unshielding for earned minutes, reliable timed re-shielding with DeviceActivityMonitor extension, and a secure parent-managed policy applied on the child's device.
- Apple must approve Family Controls distribution entitlements; unsigned IPA alone cannot validate this.
- iOS does not expose an API to directly increase Apple's built-in Screen Time allowance.
- A compliant reward mechanism would temporarily remove this app's own ManagedSettings shields and restore them using a DeviceActivityMonitor extension. It cannot bypass Apple's separate Screen Time restrictions.

## Security limitations to address before release
- The QR links two authenticated accounts; it **does not prove legal parent/guardian status**. A real guardian verification and Apple family authorization flow are still necessary.
- The local legacy parent task implementation in ParentTasks.swift is no longer shown in the main app, to avoid its insecure local parent-mode toggle.
- A child's self-reported age is not a verified age. Do not treat it as authorization.
- A child can potentially revoke app permissions or uninstall the app, subject to Apple family controls.
- Ensure child pairing confirmation, guardian approval, and account recovery policies are reviewed before distributing this to families.
- Build success and device testing are not yet confirmed.
