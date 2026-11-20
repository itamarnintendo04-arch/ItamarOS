# App Customizer SpringBoard tweak (planned)

Target UX: Add a localized **Change Name & Icon** action to an app's long-press Home Screen menu, allow changing its displayed label and icon, and provide Restore Default.

This directory documents the future tweak, not an installed or functioning jailbreak modification.

Implementation prerequisites:
- Verified compatible jailbreak and injection framework for the target iOS version
- SpringBoard-specific integration tested on physical supported devices
- Safe persistence and reversible original icon/label mapping
- Backup and recovery testing
- Language selection based on the device's active locale

TrollStore alone is not a SpringBoard tweak framework. The main app must not claim this feature is active without a supported and tested integration.
