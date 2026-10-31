#if os(iOS)
import SwiftUI
import UserNotifications
import Contacts
import CoreImage.CIFilterBuiltins
import UIKit

// Cloud mode is opt-in: it appears only after adding Supabase publishable
// configuration in project.yml and deploying messaging/supabase/migration.sql.
// The original local messenger remains available otherwise.
struct ItamarCloudConnectView: View {
    @StateObject private var client = ItamarCloudClient()
    @State private var tab = 0
    @State private var showProfile = false
    @State private var showCreate = false
    @State private var showParent = false
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Group {
                if client.signedIn {
                    VStack(spacing: 0) {
                        Picker("Section", selection: $tab) {
                            Text("Chats").tag(0)
                            Text("Channels").tag(1)
                            Text("Updates").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .padding()

                        if tab == 2 { updatesList }
                        else if tab == 1 { channelList }
                        else { chatList }
                    }
                    .navigationDestination(for: UUID.self) { id in
                        if let room = client.rooms.first(where: { $0.id == id }) {
                            ItamarCloudThreadView(client: client, room: room)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { showProfile = true } label: { Image(systemName: "person.crop.circle") }
                                .accessibilityLabel("My profile")
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            if tab != 2 {
                                Button { showCreate = true } label: { Image(systemName: "plus.circle.fill") }
                                    .accessibilityLabel("New chat or channel")
                            }
                        }
                    }
                } else {
                    ItamarCloudAuthView(client: client)
                }
            }
            .navigationTitle("Connect")
            .safeAreaInset(edge: .bottom) {
                if !error.isEmpty {
                    Text(error).font(.caption).foregroundStyle(.red)
                        .padding(8).frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                }
            }
            .sheet(isPresented: $showProfile) {
                NavigationStack { ItamarCloudProfileView(client: client) }
            }
            .sheet(isPresented: $showCreate) {
                NavigationStack {
                    ItamarCloudCreateView(client: client, kind: tab == 1 ? "channel" : "chat")
                }
            }
            .sheet(isPresented: $showParent) {
                NavigationStack { ItamarCloudParentInviteView(client: client) }
            }
            .task {
                if client.signedIn {
                    do { try await client.refresh() } catch { self.error = error.localizedDescription }
                }
            }
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
                guard client.signedIn else { return }
                Task {
                    do {
                        try await client.loadRooms()
                        try await client.loadUpdates()
                    } catch { self.error = error.localizedDescription }
                }
            }
        }
    }

    private var chatList: some View {
        List {
            Section {
                Text("End-to-end encryption is not yet implemented. Only room members can read messages through server access controls.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(client.rooms.filter { $0.kind == "chat" }) { room in
                roomRow(room)
            }
        }
        .refreshable { await refreshAll() }
        .overlay {
            if client.rooms.allSatisfy({ $0.kind != "chat" }) {
                ContentUnavailableView("No chats yet", systemImage: "bubble.left",
                    description: Text("Use + to start a conversation with a username."))
            }
        }
    }

    private var channelList: some View {
        List {
            Section("My channels") {
                ForEach(client.rooms.filter { $0.kind == "channel" }) { room in
                    roomRow(room)
                }
            }
            Section("Discover public channels") {
                Button("Refresh public channels") { Task { await refreshChannels() } }
                ForEach(client.channels.filter { channel in
                    !client.rooms.contains(where: { $0.id == channel.id })
                }) { room in
                    HStack {
                        Image(systemName: "megaphone.fill").foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text(room.title)
                            Text("Public broadcast channel").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Join") {
                            Task {
                                do { try await client.join(channel: room.id) }
                                catch { self.error = error.localizedDescription }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .refreshable { await refreshChannels() }
        .task { await refreshChannels() }
    }

    private var updatesList: some View {
        List {
            Section {
                Text("Messages from joined, unmuted chats and channels appear here. This feed refreshes while the app is open. Push alerts while closed need APNs to be configured separately.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(client.updates) { item in
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title).font(.headline)
                    Text(item.body).lineLimit(3)
                    Text(item.created_at).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .refreshable { await refreshAll() }
        .overlay {
            if client.updates.isEmpty {
                ContentUnavailableView("No updates", systemImage: "bell.slash",
                    description: Text("New messages from unmuted conversations will appear here."))
            }
        }
    }

    private func roomRow(_ room: ItamarCloudRoom) -> some View {
        HStack {
            NavigationLink(value: room.id) {
                HStack(spacing: 9) {
                    Image(systemName: room.kind == "chat" ? "bubble.left.and.bubble.right" : "megaphone.fill")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text(room.title).font(.headline)
                        Text(room.kind == "chat" ? "Private chat" : "Channel")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if room.muted == true { Image(systemName: "bell.slash.fill") }
                }
            }
            Button {
                Task {
                    do { try await client.setMuted(!(room.muted ?? false), room: room.id) }
                    catch { self.error = error.localizedDescription }
                }
            } label: {
                Image(systemName: room.muted == true ? "bell.slash" : "bell")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(room.muted == true ? "Unmute" : "Mute")
        }
    }

    private func refreshAll() async {
        do { try await client.refresh(); error = "" }
        catch { self.error = error.localizedDescription }
    }

    private func refreshChannels() async {
        do { try await client.loadRooms(); try await client.loadChannels(); error = "" }
        catch { self.error = error.localizedDescription }
    }
}

struct ItamarCloudAuthView: View {
    @ObservedObject var client: ItamarCloudClient
    @State private var email = ""
    @State private var password = ""
    @State private var register = false
    @State private var busy = false
    @State private var error = ""

    var body: some View {
        Form {
            Section {
                Text(register ? "Create a Connect account" : "Sign in to Connect")
                    .font(.title3.bold())
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                if !error.isEmpty { Text(error).foregroundStyle(.red).font(.caption) }
                if !client.status.isEmpty { Text(client.status).font(.caption) }
                Button(register ? "Create account" : "Sign in") {
                    busy = true
                    Task {
                        defer { busy = false }
                        do {
                            if register { try await client.signUp(email: email, password: password) }
                            else { try await client.signIn(email: email, password: password) }
                            password = ""
                            error = ""
                        } catch { self.error = error.localizedDescription }
                    }
                }
                .disabled(busy || !email.contains("@") || password.count < 6)
                Button(register ? "Already have an account? Sign in" : "Need an account? Register") {
                    register.toggle()
                    error = ""
                }
            }
            Section {
                Text("Accounts use the configured Supabase Auth server. Do not reuse a password from another service. The app never uploads your phone's contact list.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

private struct ItamarCloudCreateView: View {
    @ObservedObject var client: ItamarCloudClient
    @Environment(\.dismiss) private var dismiss
    let kind: String
    @State private var title = ""
    @State private var username = ""
    @State private var error = ""
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                TextField(kind == "chat" ? "Conversation name" : "Channel name", text: $title)
                if kind == "chat" {
                    TextField("Other person's username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            } footer: {
                Text(kind == "chat" ? "Only invited members can read a private chat." :
                     "Anyone signed in can discover and follow a channel; only its owner can publish.")
            }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
            Button("Create") {
                busy = true
                Task {
                    defer { busy = false }
                    do {
                        try await client.createRoom(kind: kind, title: title,
                                                    username: kind == "chat" ? username : nil)
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }
            }
            .disabled(busy || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                      (kind == "chat" && username.isEmpty))
        }
        .navigationTitle(kind == "chat" ? "New chat" : "New channel")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

private struct ItamarCloudThreadView: View {
    @ObservedObject var client: ItamarCloudClient
    let room: ItamarCloudRoom
    @State private var draft = ""
    @State private var error = ""
    @State private var working = false

    private var mayPublish: Bool { room.kind == "chat" || room.owner_id == client.userID }

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(client.messages.filter { $0.room_id == room.id }) { item in
                    HStack {
                        if item.sender_id == client.userID { Spacer(minLength: 45) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.sender_id == client.userID ? "You" : "Member")
                                .font(.caption.bold())
                            Text(item.body)
                            Text(item.created_at).font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(11)
                        .background(item.sender_id == client.userID ?
                                    Color.blue.opacity(0.2) : Color.gray.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 13))
                        if item.sender_id != client.userID { Spacer(minLength: 45) }
                    }
                }
            }
            if !error.isEmpty {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            if mayPublish {
                HStack {
                    TextField(room.kind == "chat" ? "Message" : "Channel update", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        let text = draft
                        working = true
                        Task {
                            defer { working = false }
                            do {
                                try await client.send(text: text, room: room.id)
                                draft = ""
                            } catch { self.error = error.localizedDescription }
                        }
                    } label: { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                    .disabled(working || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(.regularMaterial)
            } else {
                Text("Only channel owners can post.")
                    .font(.footnote).foregroundStyle(.secondary).padding(10)
            }
        }
        .navigationTitle(room.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await toggleMute() } } label: {
                    Image(systemName: room.muted == true ? "bell.slash" : "bell")
                }
                .accessibilityLabel(room.muted == true ? "Unmute" : "Mute")
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
        .onReceive(Timer.publish(every: 20, on: .main, in: .common).autoconnect()) { _ in
            Task { await reload() }
        }
    }

    private func reload() async {
        do { try await client.loadMessages(room: room.id) }
        catch { self.error = error.localizedDescription }
    }
    private func toggleMute() async {
        let fresh = client.rooms.first(where: { $0.id == room.id }) ?? room
        do { try await client.setMuted(!(fresh.muted ?? false), room: room.id) }
        catch { self.error = error.localizedDescription }
    }
}

struct ItamarCloudProfileView: View {
    @ObservedObject var client: ItamarCloudClient
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var username = ""
    @State private var about = ""
    @State private var error = ""
    @State private var showParent = false
    @State private var showContacts = false
    @State private var permission = ""

    var body: some View {
        Form {
            Section("My profile") {
                TextField("Display name", text: $name)
                TextField("Unique username", text: $username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("About me", text: $about)
                Button("Save profile") {
                    Task {
                        do {
                            try await client.saveProfile(name: name, username: username, about: about)
                            error = ""
                        } catch { self.error = error.localizedDescription }
                    }
                }
            }
            Section("Permissions") {
                Button("Choose contacts for local drafts") { showContacts = true }
                Button("Request notification permission") {
                    Task {
                        do {
                            let permitted = try await UNUserNotificationCenter.current()
                                .requestAuthorization(options: [.alert, .badge, .sound])
                            permission = permitted ? "Permission granted. Remote push notifications still need APNs backend configuration." : "Permission declined."
                        } catch { permission = error.localizedDescription }
                    }
                }
                if !permission.isEmpty { Text(permission).font(.caption) }
            }
            Section("Family") {
                Button("Create parent QR invitation") { showParent = true }
                Text("The parent must sign in with a verified account. Pairing doesn't reveal conversations or device data.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Button("Sign out", role: .destructive) { client.signOut(); dismiss() }
            }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
        .task {
            do {
                try await client.loadProfile()
                name = client.profile?.display_name ?? ""
                username = client.profile?.username ?? ""
                about = client.profile?.about ?? ""
            } catch { error = error.localizedDescription }
        }
        .sheet(isPresented: $showParent) {
            NavigationStack { ItamarCloudParentInviteView(client: client) }
        }
        .sheet(isPresented: $showContacts) {
            NavigationStack { ItamarContactsView() }
        }
    }
}

struct ItamarCloudParentInviteView: View {
    @ObservedObject var client: ItamarCloudClient
    @Environment(\.dismiss) private var dismiss
    @State private var code: String?
    @State private var error = ""

    private var link: URL? {
        guard let code else { return nil }
        return URL(string: "https://itamaros-web-emulator.onrender.com/parent.html?invite=\(code)")
    }
    private var qrImage: UIImage? {
        guard let link else { return nil }
        let generator = CIFilter.qrCodeGenerator()
        generator.message = Data(link.absoluteString.utf8)
        guard let image = generator.outputImage else { return nil }
        let extent = image.extent
        let scaled = image.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard extent.width > 0, let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Parent pairing").font(.title.bold())
                Text("The QR opens the official parent setup website. If the parent has a compatible ItamarOS iPhone app, the site can offer to open it.")
                    .multilineTextAlignment(.center)
                if let qrImage {
                    Image(uiImage: qrImage).interpolation(.none).resizable()
                        .scaledToFit().frame(width: 230, height: 230)
                }
                if let link { ShareLink(item: link) { Label("Share invitation", systemImage: "square.and.arrow.up") } }
                Button("Generate secure QR (15 minutes)") {
                    Task {
                        do { code = try await client.createParentInvite(); error = "" }
                        catch { self.error = error.localizedDescription }
                    }
                }
                .buttonStyle(.borderedProminent)
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
                Text("A verified, signed-in parent must explicitly accept. This does not grant access to messages or activate supervision. Do not share the QR publicly.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Parent QR")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}

// Invoked from the custom itamaros://parent?invite=… link on parent.html.
// No personal information is sent until the signed-in adult confirms.
struct ItamarCloudParentRedeemView: View {
    let inviteCode: String
    @StateObject private var client = ItamarCloudClient()
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var relationship = "Parent"
    @State private var confirmed = false
    @State private var completed = false
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Form {
                if !client.signedIn {
                    Section {
                        Text("Sign in with the parent's own verified account.")
                        ItamarCloudAuthView(client: client)
                            .frame(minHeight: 300)
                    }
                } else {
                    Section("Parent details") {
                        TextField("Your name", text: $name)
                        Picker("Relationship", selection: $relationship) {
                            Text("Parent").tag("Parent")
                            Text("Legal guardian").tag("Legal guardian")
                        }
                        Toggle("I agree to link my own account to this invitation.", isOn: $confirmed)
                    }
                    Section {
                        Text("Pairing doesn't give access to the child's chats, contacts, or location. A QR code by itself doesn't verify someone's age or legal authority.")
                            .font(.footnote)
                        if completed {
                            Label("Pairing saved securely.", systemImage: "checkmark.circle").foregroundStyle(.green)
                        } else {
                            Button("Confirm parent pairing") {
                                Task {
                                    do {
                                        try await client.redeemParentInvite(code: inviteCode, name: name, relationship: relationship)
                                        completed = true
                                        error = ""
                                    } catch { self.error = error.localizedDescription }
                                }
                            }
                            .disabled(!confirmed || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Parent setup")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
#endif
