#if os(iOS)
import SwiftUI
import Contacts

// Contact names stay on this iPhone. No address-book upload, phone-number
// matching, background sync, or contact-permission request at app startup.
struct ItamarOnlineContactsView: View {
    @State private var names = [String]()
    @State private var status = "Select Allow to read contact names on this device."
    @State private var loading = false
    private let contactStore = CNContactStore()

    var body: some View {
        List {
            Section {
                Text("ItamarOS does not upload your contacts. To message someone online, ask for their exact ItamarOS @username.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button(loading ? "Opening contacts…" : "Allow access to contacts") {
                    loading = true
                    Task {
                        do {
                            let allowed = try await contactStore.requestAccess(for: .contacts)
                            if allowed {
                                loadNames()
                            } else {
                                status = "Contact permission was declined. You can still chat using usernames."
                            }
                        } catch {
                            status = "Contacts are unavailable: \(error.localizedDescription)"
                        }
                        loading = false
                    }
                }
                .disabled(loading)
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
            Section("Names on this device") {
                ForEach(names, id: \.self) { name in
                    Label(name, systemImage: "person.crop.circle")
                }
            }
        }
        .navigationTitle("Device contacts")
    }

    private func loadNames() {
        do {
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as NSString,
                CNContactFamilyNameKey as NSString
            ]
            var results = Set<String>()
            try contactStore.enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) { contact, _ in
                let display = [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }.joined(separator: " ")
                if !display.isEmpty { results.insert(display) }
            }
            names = results.sorted()
            status = "\(names.count) contact names loaded locally. None were sent to the server."
        } catch {
            status = "Could not read contacts: \(error.localizedDescription)"
        }
    }
}
#endif
