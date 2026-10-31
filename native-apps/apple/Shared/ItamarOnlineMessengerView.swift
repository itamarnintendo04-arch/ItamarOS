#if os(iOS)
import SwiftUI
import CoreImage.CIFilterBuiltins
import UserNotifications
import UniformTypeIdentifiers

// The connected mode is enabled only after the project owner configures a
// Supabase URL + public publishable key and applies the RLS SQL migration.
// It is separate from the existing offline message drafts.
struct ItamarOnlineMessengerView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @State private var selected = 0
    @State private var showProfile = false
    @State private var showNew = false
    @State private var showChannels = false
    @State private var pollTask: Task<Void, Never>?
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Group {
                if !cloud.isSignedIn {
                    ItamarCloudLoginView()
                } else if cloud.profile == nil {
                    ItamarCloudProfileView(required: true)
                } else {
                    VStack(spacing: 0) {
                        Picker("Messages", selection: $selected) {
                            Text("Chats").tag(0)
                            Text("Channels").tag(1)
                            Text("Updates").tag(2)
                            Text("Groups").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        if !cloud.status.isEmpty {
                            Text(cloud.status).font(.caption).foregroundStyle(.secondary)
                                .padding(.horizontal)
                        }
                        List {
                            if selected == 2 {
                                if cloud.updates.isEmpty {
                                    ContentUnavailableView("No new activity", systemImage: "bell.slash",
                                        description: Text("New posts and messages from unmuted rooms appear here while connected."))
                                }
                                ForEach(cloud.updates) { update in
                                    NavigationLink {
                                        if let room = cloud.rooms.first(where: { $0.id == update.room_id }) {
                                            ItamarCloudThreadView(room: room)
                                        } else {
                                            Text("This conversation is no longer available.")
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(update.title).font(.headline)
                                            Text(update.body).lineLimit(2).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } else {
                                let kind = selected == 0 ? "chat" : (selected == 3 ? "group" : "channel")
                                ForEach(cloud.rooms.filter { $0.kind == kind }) { room in
                                    NavigationLink {
                                        ItamarCloudThreadView(room: room)
                                    } label: {
                                        HStack {
                                            Image(systemName: kind == "chat" ? "bubble.left.and.bubble.right.fill" : (kind == "group" ? "person.3.fill" : "megaphone.fill"))
                                                .foregroundStyle(.blue)
                                            VStack(alignment: .leading) {
                                                Text(room.title).font(.headline)
                                                Text(kind == "chat" ? "Private conversation" : (kind == "group" ? "Group chat" : "Broadcast channel"))
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            if room.muted == true {
                                                Image(systemName: "bell.slash").foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                if cloud.rooms.allSatisfy({ $0.kind != kind }) {
                                    ContentUnavailableView(
                                        "Nothing here yet", systemImage: kind == "chat" ? "bubble.left" : (kind == "group" ? "person.3" : "megaphone"),
                                        description: Text(kind == "chat" ? "Start a chat by username." : (kind == "group" ? "Create a group." : "Create or follow a channel."))
                                    )
                                }
                            }
                        }
                        .refreshable {
                            do { try await cloud.reload() } catch { self.error = error.localizedDescription }
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { showProfile = true } label: {
                                Image(systemName: "person.crop.circle")
                            }.accessibilityLabel("My account")
                        }
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            if selected == 1 {
                                Button { showChannels = true } label: {
                                    Image(systemName: "magnifyingglass")
                                }.accessibilityLabel("Discover channels")
                            }
                            if selected != 2 {
                                Button { showNew = true } label: {
                                    Image(systemName: "plus.circle.fill")
                                }.accessibilityLabel("New chat or channel")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Messages")
            .sheet(isPresented: $showProfile) {
                NavigationStack { ItamarCloudProfileView(required: false) }
            }
            .sheet(isPresented: $showNew) {
                NavigationStack { if selected == 3 { ItamarCreateGroupView() }
                else { ItamarCloudNewRoomView(kind: selected == 1 ? "channel" : "chat") } }
            }
            .sheet(isPresented: $showChannels) {
                NavigationStack { ItamarCloudExploreView() }
            }
            .alert("Messaging error", isPresented: Binding(
                get: { !error.isEmpty }, set: { if !$0 { error = "" } }
            )) { Button("OK") { error = "" } } message: { Text(error) }
        }
        .onAppear {
            pollTask?.cancel()
            pollTask = Task {
                while !Task.isCancelled {
                    if cloud.isSignedIn {
                        do { try await cloud.reload() }
                        catch { error = error.localizedDescription }
                    }
                    try? await Task.sleep(for: .seconds(15))
                }
            }
        }
        .onDisappear { pollTask?.cancel(); pollTask = nil }
    }
}

struct ItamarCloudLoginView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @State private var email = ""
    @State private var password = ""
    @State private var signingUp = false
    @State private var processing = false
    @State private var error = ""

    var body: some View {
        Form {
            Section("ItamarOS account") {
                Text("Sign in to send messages between devices. The account uses Supabase authentication.")
                    .font(.footnote).foregroundStyle(.secondary)
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never).keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                Toggle("Create a new account", isOn: $signingUp)
                Button(processing ? "Connecting…" : signingUp ? "Create account" : "Sign in") {
                    processing = true
                    Task {
                        do {
                            if signingUp {
                                try await cloud.signUp(email: email, password: password)
                            } else {
                                try await cloud.signIn(email: email, password: password)
                            }
                            error = ""
                        } catch { error = error.localizedDescription }
                        processing = false
                    }
                }
                .disabled(processing || email.isEmpty || password.count < 6)
                if !error.isEmpty { Text(error).font(.caption).foregroundStyle(.red) }
                if !cloud.status.isEmpty { Text(cloud.status).font(.caption) }
            }
            Section {
                Text("Never share your password. Conversations are stored in the connected project's database; end-to-end encryption is not implemented. Use block/report controls before public launch.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

struct ItamarCloudProfileView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @Environment(\.dismiss) private var dismiss
    let required: Bool
    @State private var name = ""
    @State private var username = ""
    @State private var about = ""
    @State private var error = ""
    @State private var busy = false
    @State private var showFamily = false
    @State private var permissionText = ""

    var body: some View {
        Form {
            Section("Public profile") {
                TextField("Display name", text: $name)
                TextField("Unique username", text: $username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("About", text: $about)
                Button(busy ? "Saving…" : "Save profile") {
                    busy = true
                    Task {
                        do {
                            try await cloud.saveProfile(name: name, username: username, about: about)
                            error = ""
                            if !required { dismiss() }
                        } catch { error = error.localizedDescription }
                        busy = false
                    }
                }.disabled(busy || name.isEmpty || username.isEmpty)
                if !error.isEmpty { Text(error).font(.caption).foregroundStyle(.red) }
            }
            if !required {
                Section("Chats and notifications") {
                    NavigationLink("Synced contacts, usernames and phone invitations") { ItamarConnectContactsView() }
                    NavigationLink("My shareable QR code") { ItamarMyContactQRView() }
                    NavigationLink("Verify my phone and discovery privacy") { ItamarPhoneSettingsView() }
                    NavigationLink("Device address book (optional)") { ItamarOnlineContactsView() }
                    Button("Allow message notifications") {
                        Task {
                            do {
                                let allowed = try await UNUserNotificationCenter.current()
                                    .requestAuthorization(options: [.alert, .badge, .sound])
                                permissionText = allowed ?
                                    "Permission allowed. Background push still needs APNs and a notification server." :
                                    "Notifications permission was declined."
                            } catch { permissionText = error.localizedDescription }
                        }
                    }
                    if !permissionText.isEmpty { Text(permissionText).font(.caption) }
                    Text("Mute any chat or channel from its conversation screen. New message updates are shown while the app is open.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Family") {
                    Button("Link a parent or guardian using QR") { showFamily = true }
                    Text("Linking a guardian never automatically shares private messages or grants account control.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button("Sign out", role: .destructive) {
                        cloud.signOut()
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(required ? "Create your profile" : "My account")
        .toolbar {
            if !required {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            name = cloud.profile?.display_name ?? ""
            username = cloud.profile?.username ?? ""
            about = cloud.profile?.about ?? ""
        }
        .sheet(isPresented: $showFamily) {
            NavigationStack { ItamarCloudParentInviteView() }
        }
    }
}

private struct ItamarCloudNewRoomView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @Environment(\.dismiss) private var dismiss
    let kind: String
    @State private var title = ""
    @State private var username = ""
    @State private var error = ""
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                TextField(kind == "channel" ? "Channel title" : "Conversation title", text: $title)
                if kind == "chat" {
                    TextField("Friend's @username", text: $username)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
            } footer: {
                Text(kind == "channel" ? "Anyone with an account can discover and follow public channels. Only the owner can post." :
                     "Your chat will be visible to both signed-in participants.")
            }
            Button(busy ? "Creating…" : "Create") {
                busy = true
                Task {
                    do {
                        try await cloud.createRoom(kind: kind, title: title, username: username)
                        dismiss()
                    } catch { error = error.localizedDescription }
                    busy = false
                }
            }.disabled(busy || title.isEmpty || (kind == "chat" && username.isEmpty))
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle(kind == "channel" ? "New channel" : "New chat")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
    }
}

private struct ItamarCloudExploreView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @Environment(\.dismiss) private var dismiss
    @State private var error = ""

    var body: some View {
        List {
            ForEach(cloud.channels) { channel in
                HStack {
                    Image(systemName: "megaphone.fill").foregroundStyle(.blue)
                    Text(channel.title)
                    Spacer()
                    Button("Follow") {
                        Task {
                            do {
                                try await cloud.joinChannel(channel.id)
                                dismiss()
                            } catch { error = error.localizedDescription }
                        }
                    }
                    .disabled(cloud.rooms.contains(where: { $0.id == channel.id }))
                }
            }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("Discover channels")
        .toolbar { ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
        } }
        .task { do { try await cloud.loadPublicChannels() }
                catch { error = error.localizedDescription } }
    }
}

private struct SharedAttachmentFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct ItamarCloudThreadView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    let room: ItamarCloudRoom
    @State private var messages: [ItamarCloudMessage] = []
    @State private var draft = ""
    @State private var muted = false
    @State private var error = ""
    @State private var poll: Task<Void, Never>?
    @State private var showFilePicker = false
    @State private var sharedFile: URL?

    private var canPost: Bool { room.kind != "channel" || room.owner_id == cloud.userID }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { message in
                            let mine = message.sender_id == cloud.userID
                            HStack {
                                if mine { Spacer(minLength: 45) }
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(message.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    if message.attachment_path != nil {
                                        Button {
                                            Task {
                                                do { sharedFile = try await cloud.downloadAttachment(message) }
                                                catch { error = error.localizedDescription }
                                            }
                                        } label: {
                                            Label("Open attached file", systemImage: "paperclip")
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    Text(String(message.created_at.prefix(16)).replacingOccurrences(of: "T", with: " "))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(mine ? Color.blue.opacity(0.16) : Color.gray.opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 14))
                                .frame(maxWidth: 310)
                                if !mine { Spacer(minLength: 45) }
                            }
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { scroll.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            if canPost {
                HStack {
                    TextField("Message", text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(1...4)
                    Button {
                        let toSend = draft; draft = ""
                        Task {
                            do {
                                try await cloud.send(toSend, in: room.id)
                                messages = try await cloud.messages(in: room.id)
                            } catch {
                                error = error.localizedDescription
                                draft = toSend
                            }
                        }
                    } label: { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button { showFilePicker = true } label: {
                        Image(systemName: "paperclip").font(.title2)
                    }
                    .accessibilityLabel("Attach photo, video, audio, PDF, file or contact card")
                }
                .padding().background(.regularMaterial)
            } else {
                Text("Only the channel owner can publish updates.")
                    .font(.caption).foregroundStyle(.secondary).padding()
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let file = urls.first else { return }
                Task {
                    do { try await cloud.sendAttachment(file, in: room.id)
                        messages = try await cloud.messages(in: room.id)
                    } catch { error = error.localizedDescription }
                }
            case .failure(let issue): error = issue.localizedDescription
            }
        }
        .sheet(item: Binding(
            get: { sharedFile.map { SharedAttachmentFile(url: $0) } },
            set: { if $0 == nil { sharedFile = nil } }
        )) { file in
            NavigationStack {
                VStack(spacing: 18) {
                    Image(systemName: "doc.fill").font(.system(size: 65))
                    Text(file.url.lastPathComponent)
                    ShareLink(item: file.url) {
                        Label("Share or save file", systemImage: "square.and.arrow.up")
                    }
                }
                .padding()
                .navigationTitle("Attachment")
                .toolbar { Button("Done") { sharedFile = nil } }
            }
        }
        .navigationTitle(room.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            if room.kind == "group" {
                NavigationLink("Polls and voting") {
                    ItamarGroupPollsView(room: room.id)
                }
                .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(6)
                .background(.thinMaterial)
            }
        }
        .toolbar {
            Button {
                Task {
                    do {
                        try await cloud.setMuted(!muted, roomID: room.id)
                        muted.toggle()
                    } catch { error = error.localizedDescription }
                }
            } label: {
                Image(systemName: muted ? "bell.slash.fill" : "bell.fill")
            }
            .accessibilityLabel(muted ? "Unmute updates" : "Mute updates")
        }
        .alert("Error", isPresented: Binding(get: { !error.isEmpty },
            set: { if !$0 { error = "" } })) {
            Button("OK") { error = "" }
        } message: { Text(error) }
        .onAppear {
            muted = room.muted ?? false
            poll?.cancel()
            poll = Task {
                while !Task.isCancelled {
                    do { messages = try await cloud.messages(in: room.id) }
                    catch { error = error.localizedDescription }
                    try? await Task.sleep(for: .seconds(8))
                }
            }
        }
        .onDisappear { poll?.cancel(); poll = nil }
    }
}

struct ItamarCloudParentInviteView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var error = ""

    private var url: URL? {
        guard !code.isEmpty else { return nil }
        return URL(string: "https://itamaros-web-emulator.onrender.com/parent.html?invite=\(code)")
    }
    private var qr: UIImage? {
        guard let url, let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(url.absoluteString.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        let context = CIContext()
        guard let output = filter.outputImage,
              let image = context.createCGImage(output.transformed(by: .init(scaleX: 8, y: 8)),
                                                from: output.extent.applying(.init(scaleX: 8, y: 8))) else { return nil }
        return UIImage(cgImage: image)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Invite a parent or guardian")
                    .font(.title2.bold())
                if let qr {
                    Image(uiImage: qr).interpolation(.none).resizable().scaledToFit()
                        .frame(width: 245, height: 245)
                }
                if let url {
                    ShareLink(item: url) {
                        Label("Share invitation", systemImage: "square.and.arrow.up")
                    }
                    Text("The invitation expires after 15 minutes and works once.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Generate new QR") {
                    Task {
                        do { code = try await cloud.createParentInvite(); error = "" }
                        catch { error = error.localizedDescription }
                    }
                }
                .buttonStyle(.borderedProminent)
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
                Text("The parent signs in with a confirmed email before accepting. This does not verify legal guardianship, grant chat access, or turn on surveillance.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }
        .navigationTitle("Parent QR")
        .toolbar { ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
        } }
        .task {
            if code.isEmpty {
                do { code = try await cloud.createParentInvite() }
                catch { error = error.localizedDescription }
            }
        }
    }
}

struct ItamarCloudParentRegistrationView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @Environment(\.dismiss) private var dismiss
    let inviteCode: String
    @State private var name = ""
    @State private var relation = "Parent"
    @State private var error = ""
    @State private var linked = false

    var body: some View {
        NavigationStack {
            Form {
                if !cloud.isSignedIn {
                    Section("Sign in first") {
                        ItamarCloudLoginView()
                        Text("Use the parent's own account and confirmed email.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Section("Parent or guardian details") {
                        TextField("Parent name", text: $name)
                        Picker("Relationship", selection: $relation) {
                            Text("Parent").tag("Parent")
                            Text("Legal guardian").tag("Legal guardian")
                        }
                        Button("Accept invitation") {
                            Task {
                                do {
                                    try await cloud.redeemParentInvite(
                                        code: inviteCode, name: name, relationship: relation)
                                    linked = true; error = ""
                                } catch { error = error.localizedDescription }
                            }
                        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || linked)
                        if linked {
                            Label("Account linked. No conversation access was granted.",
                                  systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                        if !error.isEmpty { Text(error).foregroundStyle(.red) }
                    }
                }
                Section {
                    Text("The link records a consent-based guardian connection only. It does not establish legal identity or permit the parent to read private chats.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Parent invitation")
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            } }
        }
    }
}
#endif
