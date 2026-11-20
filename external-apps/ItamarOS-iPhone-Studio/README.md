# ItamarOS iPhone Studio Mobile

SwiftUI iPhone app prototype for creating custom Home Screen icons and labels.

## Features
- Custom application label and icon image picker
- Export a 1024x1024 PNG icon to Photos
- iCloud backup recommendation before editing
- Instructions for creating an Open App shortcut in Apple's Shortcuts app

**Limitation:** iOS apps cannot directly replace other apps' installed icons or internal display names. This tool creates Home Screen shortcut assets only.

## Build
Open `Package.swift` in Xcode 16+ and select the iOS app target. GitHub Actions validates the Swift package on macOS. A signed IPA requires Apple signing credentials and an Xcode archive/export workflow.
