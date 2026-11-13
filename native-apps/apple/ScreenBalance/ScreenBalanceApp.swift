import SwiftUI
import FamilyControls

@main
struct ScreenBalanceApp: App {
    var body: some Scene { WindowGroup { ScreenBalanceHome().statusBarHidden().persistentSystemOverlays(.hidden) } }
}

private enum BalanceTheme {
    static let background = Color(red: 0.055, green: 0.095, blue: 0.13)
    static let panel = Color(red: 0.095, green: 0.16, blue: 0.19)
    static let accent = Color(red: 0.47, green: 0.94, blue: 0.68)
}

struct ScreenBalanceHome: View {
    @StateObject private var family = BalanceFamilyStore()
    @AppStorage("balance.onboarded") private var onboarded = false
    @AppStorage("balance.estimatedHours") private var estimatedHours = 4
    @AppStorage("balance.dailyGoal") private var dailyGoal = 3
    @AppStorage("balance.completed") private var completed = 0
    @AppStorage("balance.completedDay") private var completedDay = ""
    @State private var permissionStatus = "Not requested"
    @State private var selectedChallenge = 0
    @State private var showingChallenge = false
    @State private var showingScanner = false
    @State private var scannedCode = ""
    @State private var scannerMessage = ""

    private let challenges: [(String, String, String, Int)] = [
        ("Fresh air", "Take a 10-minute outdoor break.", "leaf.fill", 10),
        ("Stretch break", "Stretch gently for 5 minutes.", "figure.cooldown", 5),
        ("Move around", "Walk or move comfortably for 10 minutes.", "figure.walk", 10),
        ("Offline focus", "Read, draw, or create for 15 minutes.", "book.closed.fill", 15)
    ]

    var body: some View {
        ZStack {
            BalanceTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 12) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(BalanceTheme.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ItamarOS").font(.subheadline.weight(.semibold)).foregroundStyle(BalanceTheme.accent)
                            Text("Screen Balance").font(.largeTitle.bold()).foregroundStyle(.white)
                        }
                    }
                    if !family.ageConfirmed { ageSetup }
                    else if !onboarded { onboarding }
                    else {
                        dashboard
                        BalanceCloudPanel().balancePanel()
                        BalanceScreenTimePanel(childAccount: family.requiresParent).balancePanel()
                    }
                    Text("Your pace, your choice. Breaks are optional, and activities should feel comfortable.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.6))
                }
                .padding(22)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            refreshDay()
            permissionStatus = AuthorizationCenter.shared.authorizationStatus == .approved ? "Authorized" : "Not authorized"
        }
        .sheet(isPresented: $showingScanner) {
            NavigationStack {
                BalanceQRScanner(onScan: { value in
                    scannedCode = value
                    scannerMessage = "QR code scanned successfully. No activity was automatically verified."
                    showingScanner = false
                }, onFailure: { message in
                    scannerMessage = message
                    showingScanner = false
                })
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Scan QR code")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { showingScanner = false } } }
            }
        }
        .sheet(isPresented: $showingChallenge) {
            challengeSheet
                .presentationDetents([.medium])
        }
    }

    private var ageSetup: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("How old are you?").font(.title.bold())
            Text("Your age helps us choose the right parent setup. We do not need your birth date.")
                .font(.subheadline).foregroundStyle(.secondary)
            Stepper("Age: \(family.age)", value: $family.age, in: 5...100)
            Button("Continue") { family.ageConfirmed = true }
                .buttonStyle(BalanceButtonStyle())
        }.balancePanel()
    }

    private var parentPairing: some View {
        VStack(spacing: 16) {
            Text("Connect a parent").font(.title.bold())
            Text("Ask a parent to open Screen Balance on their own device and scan this code.")
                .multilineTextAlignment(.center)
            BalanceQRView(code: "itamaros-screenbalance:v1:" + family.pairingCode)
            Text("Pairing requires secure server confirmation before it can control another device.")
                .font(.caption).foregroundStyle(.orange).multilineTextAlignment(.center)
            Button("Parent setup on this device") { family.parentMode = true }
                .buttonStyle(BalanceButtonStyle())
            Button("Change age") { family.ageConfirmed = false }
                .foregroundStyle(BalanceTheme.accent)
        }.balancePanel()
    }

    private var onboarding: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Find your balance").font(.title.bold())
            Text("Start with an estimate. Apple Screen Time permission can be requested separately.")
                .foregroundStyle(.white.opacity(0.75))
            VStack(alignment: .leading, spacing: 10) {
                Text("About how many hours do you use your phone each day?")
                Stepper("\(estimatedHours) hours", value: $estimatedHours, in: 0...18)
                    .tint(BalanceTheme.accent)
                Text("What daily screen-time goal feels reasonable?")
                Stepper("\(dailyGoal) hours", value: $dailyGoal, in: 1...18)
                    .tint(BalanceTheme.accent)
            }
            Button("Start my balance journey") { onboarded = true }
                .buttonStyle(BalanceButtonStyle())
        }
        .balancePanel()
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your daily goal").foregroundStyle(.white.opacity(0.7))
                    Text("\(dailyGoal) hours").font(.system(size: 38, weight: .bold, design: .rounded))
                    Text("Your starting estimate: \(estimatedHours) hours/day")
                        .font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 45)).foregroundStyle(.yellow)
            }
            .balancePanel()

            VStack(alignment: .leading, spacing: 12) {
                Text("Apple Screen Time").font(.headline)
                Text("Permission: \(permissionStatus)")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                Text("Apple requires Family Controls authorization and an approved entitlement. Usage reports also require a DeviceActivity report extension.")
                    .font(.caption).foregroundStyle(.white.opacity(0.6))
                Button("Request Screen Time access") {
                    Task {
                        do {
                            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                            permissionStatus = AuthorizationCenter.shared.authorizationStatus == .approved ? "Authorized" : "Not authorized"
                        } catch {
                            permissionStatus = "Unavailable or not granted"
                        }
                    }
                }
                .buttonStyle(BalanceButtonStyle())
            }
            .balancePanel()

            VStack(alignment: .leading, spacing: 12) {
                Label("Camera scanner", systemImage: "qrcode.viewfinder").font(.headline)
                Text("Scan a QR code with your camera. Scanning does not prove an offline activity was completed.")
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                Button("Scan QR code") { showingScanner = true }
                    .buttonStyle(BalanceButtonStyle())
                if !scannerMessage.isEmpty { Text(scannerMessage).font(.caption).foregroundStyle(BalanceTheme.accent) }
                if !scannedCode.isEmpty { Text("Last scanned: \(scannedCode)").font(.caption).lineLimit(2) }
            }
            .balancePanel()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Offline challenges").font(.title3.bold())
                    Spacer()
                    Text("\(completed) completed today")
                        .font(.caption).foregroundStyle(BalanceTheme.accent)
                }
                ForEach(challenges.indices, id: \.self) { index in
                    let challenge = challenges[index]
                    Button {
                        selectedChallenge = index
                        showingChallenge = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: challenge.2)
                                .font(.title2)
                                .frame(width: 45, height: 45)
                                .background(BalanceTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))
                                .foregroundStyle(BalanceTheme.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(challenge.0).font(.headline)
                                Text(challenge.1).font(.caption).foregroundStyle(.white.opacity(0.65))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                    if index != challenges.count - 1 { Divider().overlay(.white.opacity(0.1)) }
                }
            }
            .balancePanel()

            Button("Adjust my goals") { onboarded = false }
                .font(.subheadline).foregroundStyle(BalanceTheme.accent)
        }
        .foregroundStyle(.white)
    }

    private var challengeSheet: some View {
        let challenge = challenges[selectedChallenge]
        return VStack(spacing: 16) {
            Image(systemName: challenge.2).font(.system(size: 46)).foregroundStyle(BalanceTheme.accent)
            Text(challenge.0).font(.title.bold())
            Text(challenge.1).multilineTextAlignment(.center)
            Text("Suggested duration: \(challenge.3) minutes")
                .foregroundStyle(.secondary)
            Button("I completed this activity") {
                refreshDay()
                completed += 1
                showingChallenge = false
            }
            .buttonStyle(BalanceButtonStyle())
            Button("Not now") { showingChallenge = false }
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BalanceTheme.background)
        .preferredColorScheme(.dark)
    }

    private func refreshDay() {
        let today = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        if completedDay != today { completedDay = today; completed = 0 }
    }
}

private struct BalanceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(BalanceTheme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(BalanceTheme.accent.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 15))
    }
}

private extension View {
    func balancePanel() -> some View {
        self.padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BalanceTheme.panel, in: RoundedRectangle(cornerRadius: 22))
    }
}
