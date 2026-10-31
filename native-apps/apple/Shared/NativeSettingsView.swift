import SwiftUI
import Foundation

struct NativeSettingsView: View {
    @AppStorage("itamaros.settings.accent") private var accent = "blue"
    @AppStorage("itamaros.settings.sounds") private var sounds = true
    @AppStorage("itamaros.settings.largeText") private var largeText = false
    @EnvironmentObject private var updates: ReleaseMonitor

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Accent", selection: $accent) {
                        Text("Blue").tag("blue")
                        Text("Green").tag("green")
                        Text("Purple").tag("purple")
                    }
                    Toggle("Larger text in games", isOn: $largeText)
                    Toggle("Game sounds preference", isOn: $sounds)
                }
                Section("Device") {
                    #if os(tvOS)
                    LabeledContent("Platform", value: "Apple TV · tvOS")
                    #elseif os(macOS)
                    LabeledContent("Platform", value: "Mac · macOS")
                    #elseif os(visionOS)
                    LabeledContent("Platform", value: "Apple Vision Pro · visionOS")
                    #else
                    LabeledContent("Platform", value: "iPhone / iPad · iOS / iPadOS")
                    #endif
                    LabeledContent("Language", value: Locale.current.identifier)
                    LabeledContent("Time zone", value: TimeZone.current.identifier)
                    LabeledContent("App version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                }
                Section("Storage") {
                    #if os(tvOS)
                    Text("tvOS manages app storage. Apps cannot move themselves to an arbitrary USB drive or replace tvOS from a USB stick.")
                    #else
                    Text("App data stays in this app's sandbox. Use the system Files app for user-selected external documents where supported.")
                    #endif
                }
                #if os(iOS)
                Section("Messages and family") {
                    NavigationLink("Profile, contacts, notifications and parent QR") {
                        ItamarProfileView()
                    }
                    Text("Chats and channels are currently local previews, not a live messaging network.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                #endif
                Section("Software Updates") {
                    Button("Check for updates") {
                        Task { await updates.check() }
                    }
                    Text(updates.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("System Settings & Privacy") {
                    Text("Wi-Fi, Bluetooth, privacy permissions, display hardware and system updates are controlled by Apple Settings, not this app.")
                    Text("This is an original native SwiftUI app. It has no embedded WebView and does not install another operating system.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
