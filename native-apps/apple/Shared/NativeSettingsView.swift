import SwiftUI
import Foundation
#if os(iOS)
import UserNotifications
#endif

struct NativeSettingsView: View {
    @State private var deviceVerificationCode=""
    @State private var deviceVerificationEmail=""
    @State private var deviceVerificationSent=false
    @State private var deviceVerificationExpiresAt=Date.distantPast
    @State private var verificationClock=Date()
    @State private var verifiedAccountID: UUID?
    @State private var deviceVerificationBusy=false
    @State private var deviceVerificationStatus=""
    @State private var disconnectOtherDevicesConfirm=false
    @State private var disconnectOtherDevicesStatus=""
    @AppStorage("itamaros.settings.accent") private var accent = "blue"
    @AppStorage("itamaros.settings.sounds") private var sounds = true
    @AppStorage("itamaros.settings.largeText") private var largeText = false
    @AppStorage("itamaros.settings.language") private var selectedLanguage = "system"
    @AppStorage("itamaros.updates.autoCheck") private var autoCheckUpdates = true
    @AppStorage("itamaros.updates.notify") private var updateNotifications = false
    @EnvironmentObject private var updates: ReleaseMonitor
    #if os(iOS)
    @AppStorage("itamaros.connect.syncEnabled") private var connectSync = true
    @EnvironmentObject private var cloud: ItamarCloudService
    #endif

    #if os(iOS)
    private var securityUnlocked: Bool {
        cloud.isSignedIn && verifiedAccountID == cloud.userID && verificationClock < deviceVerificationExpiresAt
    }
    #endif

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
                Section("App language") {
                    Picker("Language", selection: $selectedLanguage) {
                        Text("System default").tag("system")
                        Text("English").tag("en")
                        Text("עברית").tag("he")
                        Text("العربية").tag("ar")
                        Text("Español").tag("es")
                        Text("Français").tag("fr")
                        Text("Deutsch").tag("de")
                        Text("Português").tag("pt")
                        Text("Русский").tag("ru")
                        Text("日本語").tag("ja")
                        Text("简体中文").tag("zh-Hans")
                        Text("Italiano").tag("it")
                        Text("हिन्दी").tag("hi")
                        Text("Türkçe").tag("tr")
                        Text("한국어").tag("ko")
                    }
                    Text("Starts in your device language. Translations are being expanded; untranslated labels remain in English.")
                        .font(.caption).foregroundStyle(.secondary)
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
                Section("Privacy & Security") {
                    if !securityUnlocked {
                                Group {
                                    Text("Email verification required").font(.headline)
                                    Text("Verify your account email to open Privacy & Security for five minutes.")
                                    if !deviceVerificationEmail.isEmpty {
                                        Text("Code destination: " + deviceVerificationEmail).font(.caption)
                                    }
                                    if deviceVerificationSent {
                                        TextField("6-digit email code", text: $deviceVerificationCode)
                                            .keyboardType(.numberPad)
                                            .textContentType(.oneTimeCode)
                                        Button("Verify code") {
                                            Task {
                                                deviceVerificationBusy=true
                                                defer { deviceVerificationBusy=false }
                                                do {
                                                    try await cloud.verifyConnectedDevicesEmail(code:deviceVerificationCode, email:deviceVerificationEmail)
                                                    deviceVerificationExpiresAt=Date().addingTimeInterval(300)
                                                    verifiedAccountID=cloud.userID
                                                    verificationClock=Date()
                                                    deviceVerificationCode=""
                                                    deviceVerificationStatus=""
                                                } catch { deviceVerificationStatus=error.localizedDescription }
                                            }
                                        }.disabled(deviceVerificationBusy || deviceVerificationCode.count != 6)
                                    }
                                    Button(deviceVerificationSent ? "Send a new code" : "Send verification code") {
                                        Task {
                                            deviceVerificationBusy=true
                                            defer { deviceVerificationBusy=false }
                                            do {
                                                deviceVerificationEmail=try await cloud.sendConnectedDevicesEmailCode()
                                                deviceVerificationSent=true
                                                deviceVerificationStatus="Check your email for the verification code."
                                            } catch { deviceVerificationStatus=error.localizedDescription }
                                        }
                                    }.disabled(deviceVerificationBusy || !cloud.isSignedIn)
                                    if !deviceVerificationStatus.isEmpty { Text(deviceVerificationStatus).font(.caption) }
                                }
                            }
                    if securityUnlocked {
                        Text("Verified for 5 minutes").font(.caption).foregroundStyle(.secondary)
                    NavigationLink("Password & account security") {
                        List {
                            Section("Password") {
                                Text("For your security, the current account password cannot be displayed. Password changes require identity verification.")
                                    .foregroundStyle(.secondary)
                                Text("Password reset and email re-verification will be available after server-side security checks are configured.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .navigationTitle("Password & Security")
                    }
                    NavigationLink("Connected apps") {
                        List {
                            Section("Cloud Climb") {
                                Text("Manage approved Cloud Climb connections here once server-side device authorization is enabled.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .navigationTitle("Connected Apps")
                    }
                    NavigationLink("Connected devices") {
                        List {
                            if securityUnlocked {
                            Section("This device") {
                                LabeledContent("Connection", value: cloud.isSignedIn ? "Signed in" : "Not signed in")
                                LabeledContent("Device", value: UIDevice.current.name)
                                if cloud.isSignedIn {
                                    Button("Sign out on this device", role: .destructive) { cloud.signOut() }
                                }
                            }
                            Section("Other devices") {
                                Text("Revoke other sign-in sessions. Individual device names are not available yet.")
                                    .foregroundStyle(.secondary)
                                Button("Disconnect all other devices", role: .destructive) {
                                    disconnectOtherDevicesConfirm=true
                                }
                                .disabled(!cloud.isSignedIn)
                                if !disconnectOtherDevicesStatus.isEmpty {
                                    Text(disconnectOtherDevicesStatus).font(.caption)
                                }
                                Text("Existing access tokens may remain valid until they expire.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            }
                        }
                        .navigationTitle("Connected Devices")

                        .confirmationDialog("Disconnect other devices?", isPresented:$disconnectOtherDevicesConfirm) {
                            Button("Disconnect all other devices", role:.destructive) {
                                Task {
                                    do {
                                        guard securityUnlocked else { throw ItamarCloudError.unauthenticated }
                                        try await cloud.signOutOtherDevices()
                                        disconnectOtherDevicesStatus="Other sign-in sessions were revoked."
                                    } catch {
                                        disconnectOtherDevicesStatus="Unable to disconnect: " + error.localizedDescription
                                    }
                                }
                            }
                        } message: {
                            Text("Other devices will need to sign in again after their current access expires. This device stays signed in.")
                        }
                    }
                }

                    Toggle("Sync ItamarConnect chats and contacts on this device",
                           isOn:$connectSync)
                        .onChange(of:connectSync) { _,enabled in
                            cloud.setDeviceSync(enabled)
                            if enabled {
                                Task { try? await cloud.reload() }
                            }
                        }
                    Text("Switching this off stops loading account chats and contacts here. It does not delete messages already stored on the server or other devices.")
                        .font(.caption).foregroundStyle(.secondary)
                    NavigationLink("Profile, contacts, notifications and parent QR") {
                        if ItamarCloudConfig.enabled {
                            ItamarCloudProfileView(required: false)
                        } else {
                            ItamarProfileView()
                        }
                    }
                    Text(ItamarCloudConfig.enabled ?
                         "Cloud chat is enabled. Remote background push still requires APNs service setup." :
                         "Chats and channels are local previews until you configure a secure backend.")
                        
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                #endif
                Section("Software Updates") {
                    Toggle("Check automatically while the app is active",isOn:$autoCheckUpdates)
                    #if os(iOS)
                    Toggle("Notify me when a signed update is available",isOn:$updateNotifications)
                        .onChange(of:updateNotifications) { _,enabled in
                            if enabled {
                                Task {
                                    let approved = (try? await UNUserNotificationCenter.current()
                                        .requestAuthorization(options:[.alert,.badge,.sound])) ?? false
                                    if !approved { updateNotifications=false }
                                }
                            }
                        }
                    #endif
                    Text("Checks run about every 30 minutes while the app is active. iOS may suspend background activity; notifications after the app closes require a server and APNs push configuration.")
                        .font(.caption).foregroundStyle(.secondary)
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
            #if os(iOS)
            .task {
                while !Task.isCancelled {
                    verificationClock=Date()
                    try? await Task.sleep(for:.seconds(1))
                }
            }
            .onChange(of:cloud.userID) { _, _ in
                deviceVerificationExpiresAt = .distantPast
                verifiedAccountID = nil
            }
            #endif
        }
    }
}
