# ItamarOS iPhone Studio — feature status

## Implemented prototype
- iOS SwiftUI screen for custom labels and icon image selection
- Export of a 1024x1024 PNG for a Home Screen shortcut
- iCloud backup recommendation and acknowledgment
- Swift package source check workflow

## Planned — not implemented
- Signed installable IPA and proper Xcode application target
- Device detection, IPSW restore, and computer backup
- Jailbreak compatibility detection
- TrollStore installation on supported devices
- SpringBoard long-press menu tweak for changing app labels/icons

## Important
TrollStore does not always require a jailbreak, and it does not itself enable arbitrary SpringBoard modifications. A jailbreak tweak must be designed and tested for each supported iOS/SpringBoard version. No verified jailbreak is available in this project for iPhone 13 on iOS 27.2.1. Do not attempt system modification without a tested compatible method and a verified backup.
