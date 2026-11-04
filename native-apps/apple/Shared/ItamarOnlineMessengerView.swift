#if os(iOS)
import SwiftUI
import CoreImage.CIFilterBuiltins
import UserNotifications
import PhotosUI
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
    @State private var showPeople = false
    @State private var chatFilter = ""
    @State private var pollTask: Task<Void, Never>?
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Group {
                if !cloud.isSignedIn {
                    ItamarCloudLoginView()
                } else if !cloud.deviceSyncEnabled {
                    ContentUnavailableView("Cloud sync is disabled",
                        systemImage:"icloud.slash",
                        description:Text("Your local choice stops this device from loading cloud chats or contacts. Enable sync in Settings to continue."))
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
                            if selected == 0 {
                                Button { showPeople = true } label: {
                                    Label("New chat · Find people",systemImage:"person.crop.circle.badge.plus")
                                }
                            }
                            if selected == 1 {
                                Button { showChannels = true } label: {
                                    Label("Browse all channels",systemImage:"magnifyingglass")
                                }
                                ForEach(cloud.channels.filter { candidate in
                                    !cloud.rooms.contains(where:{$0.id == candidate.id})
                                }) { candidate in
                                    HStack {
                                        Label(candidate.title,systemImage:"megaphone.fill")
                                        Spacer()
                                        Button("Follow") {
                                            Task { do { try await cloud.joinChannel(candidate.id) }
                                                catch { self.error=error.localizedDescription } }
                                        }
                                    }
                                }
                            }
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
                                ForEach(cloud.rooms.filter { $0.kind == kind &&
                                    (selected != 0 || chatFilter.isEmpty ||
                                     $0.title.localizedCaseInsensitiveContains(chatFilter)) }) { room in
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
                        .searchable(text:$chatFilter,prompt:"Search chats")
                        .refreshable {
                            do {
                                try await cloud.reload()
                                if selected == 1 { try await cloud.loadPublicChannels() }
                            } catch { self.error = error.localizedDescription }
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
                                Menu {
                                    Button("New contact · Search username",systemImage:"person.crop.circle.badge.plus") {
                                        showPeople = true
                                    }
                                    Button("New group",systemImage:"person.3.fill") {
                                        selected = 3; showNew = true
                                    }
                                    Button("New channel",systemImage:"megaphone.fill") {
                                        selected = 1; showNew = true
                                    }
                                } label: {
                                    Image(systemName:"plus.circle.fill")
                                }.accessibilityLabel("Add contact, group or channel")
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
            .sheet(isPresented:$showPeople) {
                NavigationStack { ItamarPeopleSearchView() }
            }
            .onChange(of:selected) { _,tab in
                if tab == 1 {
                    Task { do { try await cloud.loadPublicChannels() }
                        catch { self.error=error.localizedDescription } }
                }
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
                        catch { self.error = error.localizedDescription }
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
    @State private var registering = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var username = ""
    @State private var phone = ""
    @State private var photo: PhotosPickerItem?
    @State private var busy = false
    @State private var error = ""
    @State private var notice = ""

    private var fieldBackground: Color { Color.white.opacity(0.12) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Spacer(minLength: 18)
                ZStack {
                    Circle().fill(.cyan.opacity(0.20)).frame(width: 140,height: 140).blur(radius: 28)
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 73,weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white,.yellow)
                        .shadow(color: .cyan.opacity(0.7),radius: 15)
                }.frame(height: 112)
                Text("ItamarOS")
                    .font(.system(size: 43,weight: .black,design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .blue,radius: 12,y: 4)
                Text(registering ? "Create your account" : "Welcome back!")
                    .font(.system(size: 22,weight: .bold,design: .rounded))
                    .foregroundStyle(.white)
                Text(registering ? "Your world. Your account." : "Sign in and pick up where you left off.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.76))
                HStack(spacing: 5) {
                    tab("Sign in",active: !registering) { registering = false; error = ""; notice = "" }
                    tab("Create account",active: registering) { registering = true; error = ""; notice = "" }
                }
                .padding(5)
                .background(.white.opacity(0.12),in: RoundedRectangle(cornerRadius: 17))
                VStack(spacing: 12) {
                    if registering {
                        field("Display name",symbol:"person.fill",value:$displayName)
                        field("Unique username",symbol:"at",value:$username)
                    }
                    HStack(spacing: 11) {
                        Image(systemName:"envelope.fill").frame(width:22)
                        TextField("Email address",text:$email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }.fieldStyle(fieldBackground)
                    HStack(spacing:11) {
                        Image(systemName:"lock.fill").frame(width:22)
                        SecureField("Password (8+ characters)",text:$password)
                            .textContentType(registering ? .newPassword : .password)
                    }.fieldStyle(fieldBackground)
                    if registering {
                        HStack(spacing:11) {
                            Image(systemName:"phone.fill").frame(width:22)
                            TextField("Phone (optional)",text:$phone)
                                .keyboardType(.phonePad)
                        }.fieldStyle(fieldBackground)
                        PhotosPicker(selection:$photo,matching:.images) {
                            Label(photo == nil ? "Add profile picture (optional)" : "Profile picture selected",
                                  systemImage:"camera.fill")
                                .frame(maxWidth:.infinity,alignment:.leading)
                                .padding(15)
                                .background(fieldBackground,in:RoundedRectangle(cornerRadius:14))
                        }
                        .onChange(of:photo) { _,item in
                            Task {
                                guard let data = try? await item?.loadTransferable(type:Data.self),
                                      let image = UIImage(data:data),
                                      let jpeg = image.jpegData(compressionQuality:0.65),
                                      jpeg.count <= 3*1024*1024 else {
                                    error = "Choose an image under 3 MB."
                                    return
                                }
                                cloud.pendingSignupAvatarJPEG = jpeg
                            }
                        }
                    }
                    Button {
                        busy = true
                        Task {
                            do {
                                if registering {
                                    try await cloud.signUp(email:email,password:password)
                                    if cloud.isSignedIn {
                                        try await cloud.saveProfile(name:displayName,username:username,about:"")
                                    } else {
                                        notice = "Account created. Your email provider may require confirmation before signing in."
                                    }
                                } else {
                                    try await cloud.signIn(email:email,password:password)
                                }
                                error = ""
                            } catch { self.error = error.localizedDescription }
                            busy = false
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if busy { ProgressView().tint(.white) }
                            Text(busy ? "Please wait…" : registering ? "Create account" : "Sign in")
                                .font(.system(size:19,weight:.bold,design:.rounded))
                            Image(systemName:"arrow.right")
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(17)
                        .background(
                            LinearGradient(colors:[Color(red:0.16,green:0.72,blue:1),
                                Color(red:0.32,green:0.27,blue:0.96)],
                                startPoint:.leading,endPoint:.trailing),
                            in:RoundedRectangle(cornerRadius:16))
                        .shadow(color:.blue.opacity(0.45),radius:12,y:5)
                    }
                    .disabled(busy || !email.contains("@") || password.count < 8 ||
                        (registering && (displayName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ||
                                          username.count < 3)))
                    .opacity(busy ? 0.7 : 1)
                    if !error.isEmpty {
                        Text(error).font(.footnote).foregroundStyle(.red)
                            .frame(maxWidth:.infinity,alignment:.leading)
                    }
                    if !notice.isEmpty {
                        Text(notice).font(.footnote).foregroundStyle(.white)
                            .frame(maxWidth:.infinity,alignment:.leading)
                    }
                }
                .padding(21)
                .background(.white.opacity(0.10),in:RoundedRectangle(cornerRadius:25))
                .overlay(RoundedRectangle(cornerRadius:25)
                    .stroke(.white.opacity(0.23),lineWidth:1))
                Text("Secure account powered by Supabase")
                    .font(.caption2).foregroundStyle(.white.opacity(0.65))
                Spacer(minLength: 22)
            }
            .padding(.horizontal,22)
            .frame(maxWidth:510)
            .frame(maxWidth:.infinity)
        }
        .background(
            LinearGradient(colors:[Color(red:0.025,green:0.075,blue:0.23),
                Color(red:0.09,green:0.23,blue:0.58),
                Color(red:0.28,green:0.14,blue:0.55)],
                startPoint:.topLeading,endPoint:.bottomTrailing)
                .ignoresSafeArea()
        )
    }

    private func tab(_ label:String,active:Bool,action:@escaping ()->Void)->some View {
        Button(action:action) {
            Text(label).font(.system(size:15,weight:.bold,design:.rounded))
                .foregroundStyle(active ? Color(red:0.08,green:0.18,blue:0.4) : .white)
                .frame(maxWidth:.infinity).padding(.vertical,12)
                .background(active ? Color.white : Color.clear,
                            in:RoundedRectangle(cornerRadius:13))
        }.buttonStyle(.plain)
    }
    private func field(_ title:String,symbol:String,value:Binding<String>)->some View {
        HStack(spacing:11) {
            Image(systemName:symbol).frame(width:22)
            TextField(title,text:value).textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }.fieldStyle(fieldBackground)
    }
}

private struct ItamarAuthFieldStyle:ViewModifier {
    let color:Color
    func body(content:Content)->some View {
        content
            .foregroundStyle(.white)
            .tint(.cyan)
            .padding(15)
            .background(color,in:RoundedRectangle(cornerRadius:14))
    }
}
private extension View {
    func fieldStyle(_ color:Color)->some View {
        modifier(ItamarAuthFieldStyle(color:color))
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
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarPath: String?
    @State private var readReceipts = true

    var body: some View {
        Form {
            Section("Public profile") {
                if let url = cloud.publicAvatarURL(avatarPath) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { ProgressView() }
                    .frame(width:90,height:90).clipShape(Circle())
                }
                PhotosPicker(selection:$avatarItem,matching:.images) {
                    Label("Choose profile photo",systemImage:"camera")
                }
                .onChange(of:avatarItem) { _,new in
                    guard let new else { return }
                    Task {
                        do {
                            guard let data=try await new.loadTransferable(type:Data.self),
                                  let image=UIImage(data:data),
                                  let jpeg=image.jpegData(compressionQuality:0.65) else {
                                throw ItamarCloudError.badResponse("Unable to open photo")
                            }
                            avatarPath=try await cloud.uploadAvatarJPEG(jpeg)
                            try await cloud.updateProfilePreferences(avatar:avatarPath,receipts:readReceipts)
                        } catch { self.error=error.localizedDescription }
                    }
                }
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
                        } catch { self.error = error.localizedDescription }
                        busy = false
                    }
                }.disabled(busy || name.isEmpty || username.isEmpty)
                if !error.isEmpty { Text(error).font(.caption).foregroundStyle(.red) }
            }
            if !required {
                Section("Chats and notifications") {
                    Toggle("Send and receive read receipts",isOn:$readReceipts)
                        .onChange(of:readReceipts) { _,enabled in
                            Task {
                                do { try await cloud.updateProfilePreferences(avatar:avatarPath,receipts:enabled) }
                                catch { self.error=error.localizedDescription }
                            }
                        }
                    Text("Turning off read receipts prevents others seeing your blue checks and prevents you seeing theirs.")
                        .font(.caption).foregroundStyle(.secondary)
                    NavigationLink("Synced contacts, usernames and phone invitations") { ItamarConnectContactsView() }
                    NavigationLink("My shareable QR code") { ItamarMyContactQRView() }
                    NavigationLink("Verify my phone and discovery privacy") { ItamarPhoneSettingsView() }
                    NavigationLink("Device address book (optional)") { ItamarOnlineContactsView() }
                    Button("Enable real chat Push notifications") {
                        Task {
                            let allowed=await ItamarPushAppDelegate.requestOptIn()
                            if allowed {
                                await cloud.registerDeviceForPushIfAvailable()
                                permissionText="iPhone push registration requested. APNs signing and server credentials are needed to deliver."
                            } else {
                                permissionText="Notifications permission was declined or unavailable."
                            }
                        }
                    }
                    Button("Disable chat Push on this iPhone") {
                        Task {
                            await cloud.unregisterPushDevice()
                            permissionText="Chat push disabled on this device."
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
                        Task {
                            await cloud.unregisterPushDevice()
                            cloud.signOut()
                            dismiss()
                        }
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
            avatarPath = cloud.profile?.avatar_path
            readReceipts = cloud.profile?.read_receipts_enabled ?? true
        }
        .sheet(isPresented: $showFamily) {
            NavigationStack { ItamarCloudParentInviteView() }
        }
    }
}

private private struct ItamarPeopleSearchView:View {
    @EnvironmentObject private var cloud:ItamarCloudService
    @Environment(\.dismiss) private var dismiss
    @State private var query=""
    @State private var results:[ItamarCloudProfile]=[]
    @State private var error=""
    @State private var busy=false

    var body:some View {
        List {
            if query.trimmingCharacters(in:.whitespacesAndNewlines).count < 2 {
                ContentUnavailableView("Find a contact",systemImage:"person.crop.circle.badge.magnifyingglass",
                    description:Text("Search by username or display name."))
            }
            ForEach(results,id:\.id) { person in
                HStack(spacing:12) {
                    if let url=cloud.publicAvatarURL(person.avatar_path) {
                        AsyncImage(url:url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName:"person.crop.circle.fill")
                        }
                        .frame(width:45,height:45).clipShape(Circle())
                    } else {
                        Image(systemName:"person.crop.circle.fill")
                            .font(.system(size:42)).foregroundStyle(.blue)
                    }
                    VStack(alignment:.leading) {
                        Text(person.display_name).font(.headline)
                        Text("@"+person.username).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Chat") {
                        busy=true
                        Task {
                            do {
                                try await cloud.createRoom(kind:"chat",
                                    title:person.display_name,username:person.username)
                                dismiss()
                            } catch { self.error=error.localizedDescription }
                            busy=false
                        }
                    }.disabled(busy)
                }
            }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }
        .searchable(text:$query,prompt:"Search people by name or @username")
        .onChange(of:query) { _,term in
            results=[]
            if term.trimmingCharacters(in:.whitespacesAndNewlines).count >= 2 {
                Task {
                    try? await Task.sleep(for:.milliseconds(350))
                    guard query == term else {return}
                    do { results=try await cloud.searchPeople(term);error="" }
                    catch {error=error.localizedDescription}
                }
            }
        }
        .navigationTitle("Find people")
        .toolbar { ToolbarItem(placement:.confirmationAction) {
            Button("Done") {dismiss()}
        }}
    }
}

struct ItamarCloudNewRoomView: View {
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
                    } catch { self.error = error.localizedDescription }
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
                            } catch { self.error = error.localizedDescription }
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
                catch { self.error = error.localizedDescription } }
    }
}

private func firstItamarLink(_ text:String) -> URL? {
    let detector=try? NSDataDetector(types:NSTextCheckingResult.CheckingType.link.rawValue)
    let range=NSRange(text.startIndex..<text.endIndex,in:text)
    return detector?.matches(in:text,range:range).compactMap{$0.url}
        .first(where:{$0.scheme == "https" || $0.scheme == "http"})
}

private struct OpenedOnceText: Identifiable {
    let id = UUID()
    let body: String
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
    @State private var openedOnce: OpenedOnceText?
    @State private var editingID: UUID?
    @State private var sendOnce = false
    @State private var receipts = [UUID:ItamarReceiptSummary]()
    @State private var reactionCounts = [UUID:[ItamarReactionCount]]()
    @State private var replyTo: UUID?
    @State private var expiresAfter = 0
    @State private var reportTarget: UUID?
    @State private var blockTarget: UUID?
    @StateObject private var voiceRecorder = ItamarVoiceNoteRecorder()

    private var canPost: Bool { room.kind != "channel" || room.owner_id == cloud.userID }


    private func bubble(_ message: ItamarCloudMessage) -> some View {
        ItamarMessageBubbleView(
                                message:message,
                                ownMessage:message.sender_id == cloud.userID,
                                receipt:receipts[message.id],
                                reactionCounts:reactionCounts[message.id] ?? [],
                                repliedText:messages.first(where:{$0.id == message.reply_to})?
                                    .body,
                                onReply:{ replyTo=message.id },
                                onEdit:{ draft=message.body;editingID=message.id },
                                onDelete:{ Task {
                                    do { try await cloud.deleteMessage(id:message.id);await reloadThread() }
                                    catch { self.error=error.localizedDescription }
                                }},
                                onViewOnce:{ Task {
                                    do {
                                        let content=try await cloud.openOnceText(message:message.id)
                                        openedOnce=OpenedOnceText(body:content)
                                    } catch { self.error=error.localizedDescription }
                                }},
                                onFile:{ Task {
                                    do { sharedFile=try await cloud.downloadAttachment(message) }
                                    catch { self.error=error.localizedDescription }
                                }},
                                onReact:{ emoji in Task {
                                    do {
                                        try await cloud.setReaction(message:message.id,emoji:emoji)
                                        await reloadThread()
                                    } catch { self.error=error.localizedDescription }
                                }},
                                onReport:{ reportTarget=message.id },
                                onBlock:{ blockTarget=message.sender_id }
                            )
    }

    private var chatScrollView: some View {
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { message in
                            bubble(message)
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
    }

    @ViewBuilder
    private var chatComposer: some View {

            if canPost {
                if replyTo != nil {
                    HStack {
                        Text("Replying to message").font(.caption.bold())
                        Spacer()
                        Button("Cancel") { replyTo=nil }
                    }.padding(.horizontal)
                }
                if editingID != nil {
                    HStack {
                        Text("Editing message").font(.caption.bold())
                        Spacer()
                        Button("Cancel") { editingID=nil;draft="" }
                    }.padding(.horizontal)
                } else {
                    HStack {
                        Toggle("View once (text)",isOn:$sendOnce)
                        Picker("Disappearing",selection:$expiresAfter) {
                            Text("Keep").tag(0)
                            Text("1h").tag(3600)
                            Text("1d").tag(86400)
                            Text("7d").tag(604800)
                        }.frame(maxWidth:170)
                    }.font(.caption).padding(.horizontal)
                }
                HStack {
                    TextField("Message", text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(1...4)
                    Button {
                        let toSend = draft; draft = ""
                        Task {
                            do {
                                if let edit=editingID {
                                    try await cloud.editMessage(id:edit,text:toSend)
                                    editingID=nil
                                } else if let reply=replyTo {
                                    try await cloud.sendReply(room:room.id,to:reply,body:toSend)
                                    replyTo=nil
                                } else if sendOnce {
                                    try await cloud.sendOnceText(room:room.id,text:toSend)
                                    sendOnce=false
                                } else if expiresAfter>0 {
                                    try await cloud.sendDisappearing(room:room.id,body:toSend,seconds:expiresAfter)
                                } else {
                                    try await cloud.send(toSend,in:room.id)
                                }
                                await reloadThread()
                            } catch {
                                self.error = error.localizedDescription
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

                if voiceRecorder.recording {
                    HStack(spacing:14) {
                        Label("Recording voice note…",systemImage:"mic.fill")
                            .foregroundStyle(.red)
                        Button("Stop and send") {
                            if let file=voiceRecorder.finish() {
                                Task {
                                    defer { try? FileManager.default.removeItem(at:file) }
                                    do {
                                        try await cloud.sendAttachment(file,in:room.id)
                                        await reloadThread()
                                    } catch { self.error=error.localizedDescription }
                                }
                            }
                        }
                        Button("Discard") { voiceRecorder.discard() }
                    }.font(.caption)
                } else {
                    Button {
                        Task {
                            do { try await voiceRecorder.start() }
                            catch { self.error=error.localizedDescription }
                        }
                    } label: {
                        Label("Record voice message (up to 90 seconds)",systemImage:"mic")
                    }
                    .font(.caption)
                }

            } else {
                Text("Only the channel owner can publish updates.")
                    .font(.caption).foregroundStyle(.secondary).padding()
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            chatScrollView
            chatComposer
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let file = urls.first else { return }
                Task {
                    do { try await cloud.sendAttachment(file, in: room.id)
                        messages = try await cloud.messages(in: room.id)
                    } catch { self.error = error.localizedDescription }
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
        .sheet(item:$openedOnce) { item in
            NavigationStack {
                VStack(spacing:16) {
                    Text("View-once text").font(.title2.bold())
                    Text(item.body).textSelection(.disabled)
                    Text("This message is shown only once in the app. Screenshots cannot be prevented.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding().navigationTitle("Opened message")
                .toolbar { Button("Close") { openedOnce=nil } }
            }
        }
        .navigationTitle(room.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            if room.kind == "group" {
                HStack {
                    NavigationLink("Group info and invites") { ItamarGroupInfoView(room:room) }
                    Spacer(minLength:10)
                    NavigationLink("Polls and voting") { ItamarGroupPollsView(room:room.id) }
                }
                .font(.subheadline.bold()).padding(8)
                .background(.thinMaterial)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        do {
                            try await cloud.setMuted(!muted, roomID: room.id)
                            muted.toggle()
                        } catch { self.error = error.localizedDescription }
                    }
                } label: {
                    Image(systemName: muted ? "bell.slash.fill" : "bell.fill")
                }
                .accessibilityLabel(muted ? "Unmute updates" : "Mute updates")
            }
        }
        .confirmationDialog("Report this message",isPresented:Binding(
            get:{ reportTarget != nil },
            set:{ if !$0 { reportTarget=nil } }
        ),titleVisibility:.visible) {
            ForEach(["Spam","Harassment","Threats","Other"],id:\.self) { reason in
                Button(reason) {
                    guard let id=reportTarget else { return }
                    reportTarget=nil
                    Task {
                        do {
                            try await cloud.reportMessage(id,reason:reason)
                            error="Report saved. No automated moderator review is available yet."
                        } catch { self.error=error.localizedDescription }
                    }
                }
            }
            Button("Cancel",role:.cancel) { reportTarget=nil }
        }
        .confirmationDialog("Block this user?",isPresented:Binding(
            get:{ blockTarget != nil },
            set:{ if !$0 { blockTarget=nil } }
        ),titleVisibility:.visible) {
            Button("Block",role:.destructive) {
                guard let id=blockTarget else { return }
                blockTarget=nil
                Task {
                    do { try await cloud.blockUser(id); error="User blocked." }
                    catch { self.error=error.localizedDescription }
                }
            }
            Button("Cancel",role:.cancel) { blockTarget=nil }
        } message: {
            Text("Blocking prevents new contact but does not erase previous messages.")
        }
        .alert("Message", isPresented: Binding(get: { !error.isEmpty },
            set: { if !$0 { error = "" } })) {
            Button("OK") { error = "" }
        } message: { Text(error) }
        .onAppear {
            muted = room.muted ?? false
            poll?.cancel()
            poll = Task {
                while !Task.isCancelled {
                    await reloadThread()
                    try? await Task.sleep(for: .seconds(8))
                }
            }
        }
        .onDisappear {
            poll?.cancel()
            poll = nil
            if voiceRecorder.recording { voiceRecorder.discard() }
        }
    }
    private func reloadThread() async {
        do {
            let latest=try await cloud.messages(in:room.id)
            messages=latest
            // A conversation is 'read' only after it is actually opened.
            try await cloud.acknowledge(room:room.id,opened:true)
            receipts=(try? await cloud.receiptSummaries(for:latest)) ?? [:]
            reactionCounts=(try? await cloud.reactions(for:latest.map{$0.id})) ?? [:]
        } catch { self.error=error.localizedDescription }
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
                        catch { self.error = error.localizedDescription }
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
                catch { self.error = error.localizedDescription }
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
                                } catch { self.error = error.localizedDescription }
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
