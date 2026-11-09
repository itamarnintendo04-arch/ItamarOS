import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

/// Requires Apple's Family Controls entitlement on the installed, signed application.
/// Selecting apps and enabling shields are real ManagedSettings operations.
@MainActor
final class BalanceScreenTimeManager: ObservableObject {
    @Published var selection = FamilyActivitySelection()
    @Published var isPickerPresented = false
    @Published var isShieldEnabled = false
    @Published var status = "Choose apps to limit after Apple authorization."
    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("ItamarOSBalance"))
    private let center = AuthorizationCenter.shared

    func authorize(childAccount: Bool) async {
        do {
            try await center.requestAuthorization(for: childAccount ? .child : .individual)
            status = center.authorizationStatus == .approved ? "Apple Screen Time access approved." : "Authorization not approved."
        } catch {
            status = "Authorization failed: \(error.localizedDescription)"
        }
    }

    func applyShields() {
        guard center.authorizationStatus == .approved else {
            status = "Screen Time permission is required."
            return
        }
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
            status = "Select at least one app or category first."
            return
        }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        isShieldEnabled = true
        status = "Selected apps are shielded on this device."
    }

    func clearShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        isShieldEnabled = false
        status = "App shields cleared on this device."
    }
}

struct BalanceScreenTimePanel: View {
    @StateObject private var manager = BalanceScreenTimeManager()
    let childAccount: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Apple Screen Time controls", systemImage: "hourglass.circle").font(.headline)
            Text(manager.status).font(.caption).foregroundStyle(.secondary)
            Button("Request Apple authorization") {
                Task { await manager.authorize(childAccount: childAccount) }
            }.buttonStyle(.borderedProminent)
            Button("Choose apps and categories") { manager.isPickerPresented = true }
                .buttonStyle(.bordered)
            Button("Shield selected apps") { manager.applyShields() }
                .buttonStyle(.bordered)
            if manager.isShieldEnabled {
                Button("Clear shields on this device") { manager.clearShields() }
                    .buttonStyle(.bordered)
            }
            Text("This controls selected app shields only. Reward minutes, timed automatic relocking, and remote parent approval require a DeviceActivity monitor extension and secure family pairing.")
                .font(.caption).foregroundStyle(.orange)
        }
        .familyActivityPicker(isPresented: $manager.isPickerPresented, selection: $manager.selection)
    }
}
