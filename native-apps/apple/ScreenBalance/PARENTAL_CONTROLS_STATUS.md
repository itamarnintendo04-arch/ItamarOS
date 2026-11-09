# Screen Balance parent-control implementation status

## Implemented in the iOS app
- Age selection on first launch. Under-13 users are shown a QR code for a parent to scan.
- QR image generation and camera QR reading.
- Parent-facing local task CRUD (add, rename, edit description, edit reward, delete).
- Recurring tasks, local completion approvals, per-task adjustable reward minutes, local persistence.
- Existing FamilyControls individual authorization request (subject to Apple's entitlement approval).

## Not yet implemented (do not describe as functional)
- The QR is a pairing **invitation**, not a verified or secure parent-child connection. Scanning only stores the code locally on the scanning phone.
- The parent dashboard is a local prototype; it is **not access controlled**. A child can open it on the same device. It must not be used as a real parent authorization boundary.
- Tasks and approvals do **not** sync between devices. A verified parent account, expiring pairing challenges, backend ACLs, and push/realtime updates are required.
- Reward minutes are recorded as app data only. They do **not** extend iOS Screen Time or remove application shields.
- Actual iOS enforcement requires Apple's Family Controls entitlement approval, FamilyActivityPicker, DeviceActivity monitor/report extensions, ManagedSettings shields, and an entitlement-approved signed build. Apple's native Screen Time limits cannot be modified arbitrarily by third-party apps.
- For under-13 family authorization, use Apple's family/child authorization flow where eligible; individual authorization is not a substitute for parent approval.
- Parent role must be verified server-side; never rely on a local toggle, an unverified QR, or self-reported age for security.

## Next steps
1. Add authenticated parent and child account roles, with parent verified through Apple family authorization or a secure guardian-verification flow.
2. Add server-backed one-time QR pairing and authenticated device ownership checks.
3. Sync tasks and approvals with row-level authorization and audit logs.
4. Add FamilyActivityPicker, DeviceActivityMonitor extension and ManagedSettingsStore; verify the actual shield and reward lifecycle on a physical iPhone.
5. Add automated builds/tests and complete a successful signed-device test.
