#if os(iOS)
import SwiftUI
import Contacts
import UserNotifications

// A working offline UI. Other users cannot receive these messages without a backend.
struct ItamarMessengerView: View {
    @EnvironmentObject private var store: ItamarMessagesStore
    @State private var section = 0
    @State private var showNew = false
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Messages section", selection: $section) {
                    Text("Chats").tag(0)
                    Text("Channels").tag(1)
                    Text("Updates").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                if section == 2 {
                    List {
                        Section {
                            Label("Activity on this device only. Muted chats and channels do not appear here.", systemImage: "lock.shield")
                                .font(.footnote)
                        }
                        ForEach(store.visibleActivities) { event in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(event.title).font(.headline)
                                Text(event.detail).foregroundStyle(.secondary)
                                Text(event.date, style: .relative)
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .overlay {
                        if store.visibleActivities.isEmpty {
                            ContentUnavailableView("No updates", systemImage: "bell.slash",
                                description: Text("Activity from unmuted local chats and channels appears here."))
                        }
                    }
                } else {
                    let kind: ItamarThread.Kind = section == 0 ? .chat : .channel
                    List {
                        Section {
                            Text("On-device preview · These messages are not sent to other phones.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        ForEach(store.threads.filter { $0.kind == kind }) { thread in
                            NavigationLink(value: thread.id) {
                                HStack(spacing: 12) {
                                    Image(systemName: kind == .chat ? "bubble.left.and.bubble.right.fill" : "megaphone.fill")
                                        .foregroundStyle(.blue)
                                        .frame(width: 35)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(thread.title).font(.headline)
                                        Text(thread.messages.last?.text ?? (kind == .chat ? "Start a local chat" : "Write the first update"))
                                            .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    if thread.muted { Image(systemName: "bell.slash.fill").foregroundStyle(.secondary) }
                                }
                            }
                        }
                        .onDelete { offsets in
                            let candidates = store.threads.filter { $0.kind == kind }
                            for offset in offsets {
                                if candidates.indices.contains(offset) { store.deleteThread(candidates[offset].id) }
                            }
                        }
                    }
                    .overlay {
                        if store.threads.allSatisfy({ $0.kind != kind }) {
                            ContentUnavailableView(kind == .chat ? "No chats yet" : "No channels yet",
                                systemImage: kind == .chat ? "bubble.left" : "megaphone",
                                description: Text("Tap + to create a private local draft."))
                        }
                    }
                    .navigationDestination(for: UUID.self) { threadID in
                        ItamarThreadView(threadID: threadID)
                    }
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showProfile = true
                    } label: { Image(systemName: "person.crop.circle") }
                    .accessibilityLabel("My profile")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if section != 2 {
                        Button {
                            showNew = true
                        } label: { Image(systemName: "plus.circle.fill") }
                        .accessibilityLabel("Create chat or channel")
                    }
                }
            }
            .sheet(isPresented: $showNew) {
                ItamarNewThreadView(kind: section == 0 ? .chat : .channel)
            }
            .sheet(isPresented: $showProfile) {
                NavigationStack { ItamarProfileView() }
            }
        }
    }
}

private struct ItamarNewThreadView: View {
    @EnvironmentObject private var store: ItamarMessagesStore
    @Environment(\.dismiss) private var dismiss
    let kind: ItamarThread.Kind
    @State private var title = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(kind == .chat ? "Conversation name" : "Channel name", text: $title)
                        .textInputAutocapitalization(.words)
                } footer: {
                    Text("Stored privately on this device. Other people cannot join or see it yet.")
                }
                Button("Create") {
                    store.createThread(title: title, kind: kind)
                    dismiss()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle(kind == .chat ? "New chat" : "New channel")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct ItamarThreadView: View {
    @EnvironmentObject private var store: ItamarMessagesStore
    @Environment(\.dismiss) private var dismiss
    let threadID: UUID
    @State private var message = ""
    @State private var showDeleteConfirmation = false

    private var thread: ItamarThread? { store.threads.first { $0.id == threadID } }

    var body: some View {
        VStack(spacing: 0) {
            if let thread {
                ScrollViewReader { scroll in
                    ScrollView {
                        LazyVStack(alignment: .trailing, spacing: 12) {
                            ForEach(thread.messages) { item in
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(item.text).frame(maxWidth: .infinity, alignment: .leading)
                                    Text(item.createdAt, style: .time).font(.caption2).foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
                                .frame(maxWidth: 300, alignment: .trailing)
                                .id(item.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: thread.messages.count) { _, _ in
                        if let last = thread.messages.last {
                            withAnimation { scroll.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                HStack(spacing: 10) {
                    TextField(thread.kind == .channel ? "New channel post" : "Message", text: $message, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        store.send(text: message, in: threadID)
                        message = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.title2)
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(.regularMaterial)
            } else {
                ContentUnavailableView("Conversation unavailable", systemImage: "bubble.left")
            }
        }
        .navigationTitle(thread?.title ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let thread {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        store.setMuted(!thread.muted, for: threadID)
                    } label: {
                        Image(systemName: thread.muted ? "bell.slash.fill" : "bell.fill")
                    }
                    .accessibilityLabel(thread.muted ? "Unmute" : "Mute")
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: { Image(systemName: "trash") }
                }
            }
        }
        .confirmationDialog("Delete this local conversation?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                store.deleteThread(threadID)
                dismiss()
            }
        } message: {
            Text("Messages stored on this device will be removed.")
        }
    }
}

struct ItamarProfileView: View {
    @EnvironmentObject private var store: ItamarMessagesStore
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var username = ""
    @State private var about = ""
    @State private var errorText: String?
    @State private var showParent = false
    @State private var showContacts = false
    @State private var notificationsStatus = ""

    var body: some View {
        Form {
            Section("My profile") {
                TextField("Display name", text: $displayName)
                TextField("Username (no @)", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("About me", text: $about)
                if let errorText { Text(errorText).foregroundStyle(.red).font(.caption) }
                Button("Save profile") {
                    errorText = store.updateProfile(name: displayName, username: username, description: about)
                }
                Text("Names and usernames are local. Public username uniqueness requires an account service.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Privacy & permissions") {
                Button("Choose contacts to use in local drafts") { showContacts = true }
                Button("Request notification permission") {
                    Task {
                        do {
                            let allowed = try await UNUserNotificationCenter.current()
                                .requestAuthorization(options: [.alert, .badge, .sound])
                            store.setNotificationsPreferred(allowed)
                            notificationsStatus = allowed ? "Allowed. Remote message alerts are not available until a server is connected." : "Permission was not granted."
                        } catch {
                            notificationsStatus = "Unable to request notifications: \(error.localizedDescription)"
                        }
                    }
                }
                if !notificationsStatus.isEmpty {
                    Text(notificationsStatus).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Family") {
                Button("Set up a parent with a QR code") { showParent = true }
                Text("A parent can complete a local registration preview; actual account linking and verification require a secure server.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("My profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            displayName = store.profile.name
            username = store.profile.username
            about = store.profile.description
        }
        .sheet(isPresented: $showParent) {
            NavigationStack { ItamarParentInviteView() }
        }
        .sheet(isPresented: $showContacts) {
            NavigationStack { ItamarContactsView() }
        }
    }
}

struct ItamarContactsView: View {
    @EnvironmentObject private var store: ItamarMessagesStore
    @Environment(\.dismiss) private var dismiss
    @State private var contactNames = [String]()
    @State private var status = "Contacts are never uploaded. Only names are read after permission."
    private let contacts = CNContactStore()

    var body: some View {
        List {
            Section {
                Text(status).font(.footnote).foregroundStyle(.secondary)
                Button("Allow access to contacts") {
                    Task {
                        do {
                            let permitted = try await contacts.requestAccess(for: .contacts)
                            if permitted { loadContacts() } else { status = "Contacts access was declined." }
                        } catch {
                            status = "Contacts unavailable: \(error.localizedDescription)"
                        }
                    }
                }
            }
            Section("Create a private local draft") {
                ForEach(contactNames, id: \.self) { name in
                    Button(name) {
                        store.createThread(title: name, kind: .chat)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle("Contacts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
        }
    }

    private func loadContacts() {
        do {
            var names = [String]()
            let keys: [CNKeyDescriptor] = [CNContactGivenNameKey as NSString, CNContactFamilyNameKey as NSString]
            let request = CNContactFetchRequest(keysToFetch: keys)
            try contacts.enumerateContacts(with: request) { contact, _ in
                let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                if !name.isEmpty { names.append(name) }
            }
            contactNames = Array(Set(names)).sorted()
            status = "Choose a contact to name a private local draft. No messages are sent to them."
        } catch {
            status = "Unable to read contacts: \(error.localizedDescription)"
        }
    }
}
#endif
