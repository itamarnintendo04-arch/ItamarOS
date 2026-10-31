#if os(iOS)
import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct ItamarParentRoute: Identifiable {
    let id = UUID()
    let inviteCode: String
}

struct ItamarParentInviteView: View {
    @EnvironmentObject private var store: ItamarMessagesStore
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCode = ""

    private var invitationLink: URL? {
        guard !inviteCode.isEmpty else { return nil }
        return URL(string: "https://itamaros-web-emulator.onrender.com/parent.html?invite=\(inviteCode)")
    }

    private var qrImage: UIImage? {
        guard let invitationLink else { return nil }
        let generator = CIFilter.qrCodeGenerator()
        generator.message = Data(invitationLink.absoluteString.utf8)
        generator.correctionLevel = "M"
        let context = CIContext()
        guard let output = generator.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 9, y: 9))
        guard let image = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: image)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "person.2.badge.key.fill")
                    .font(.largeTitle).foregroundStyle(.blue)
                Text("Invite a parent").font(.title2.bold())
                Text("Ask your parent to scan this QR code with their own phone.")
                    .multilineTextAlignment(.center)
                if let image = qrImage {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 235, height: 235)
                        .padding(12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18))
                        .accessibilityLabel("Parent invite QR code")
                }
                if let invitationLink {
                    ShareLink(item: invitationLink) {
                        Label("Share invitation link", systemImage: "square.and.arrow.up")
                    }
                    Button("Copy link") {
                        UIPasteboard.general.url = invitationLink
                    }
                }
                Button("Generate a new QR code") {
                    inviteCode = store.createParentInvitation()
                }
                .buttonStyle(.bordered)

                Text("Setup preview only: the code has no personal details, but it is not yet redeemable across devices. To verify and link a parent's account, ItamarOS needs a secure server. Do not treat this as active parental supervision.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .navigationTitle("Parent QR")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        .onAppear {
            inviteCode = store.invitation ?? store.createParentInvitation()
        }
    }
}

struct ItamarParentRegistrationView: View {
    @EnvironmentObject private var store: ItamarMessagesStore
    @Environment(\.dismiss) private var dismiss
    let inviteCode: String
    @State private var name = ""
    @State private var email = ""
    @State private var relationship = "Parent"
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Parent details") {
                    TextField("Parent name", text: $name)
                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    Picker("Relationship", selection: $relationship) {
                        Text("Parent").tag("Parent")
                        Text("Legal guardian").tag("Legal guardian")
                    }
                }
                Section {
                    Text("Invitation code: \(inviteCode.prefix(8))…")
                        .font(.caption.monospaced())
                    Text("This saves the details on this device only. The original inviting phone will NOT be notified or linked. Real verification requires a backend and parent consent.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button("Save on this device") {
                    store.saveLocalParent(name: name, email: email,
                                          relationship: relationship, code: inviteCode)
                    saved = true
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if saved {
                    Label("Saved locally — not linked to another account.", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }
            .navigationTitle("Parent setup")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
#endif
