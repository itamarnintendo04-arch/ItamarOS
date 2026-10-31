#if os(iOS)
import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import PhotosUI

private func itamarQR(_ value: String) -> UIImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(value.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage else { return nil }
    let expanded = output.transformed(by: CGAffineTransform(scaleX: 9, y: 9))
    guard let image = CIContext().createCGImage(expanded, from: expanded.extent) else { return nil }
    return UIImage(cgImage: image)
}

struct ItamarConnectContactsView: View {
    let initialUsername: String?
    init(initialUsername: String? = nil) { self.initialUsername = initialUsername }
    @EnvironmentObject private var cloud: ItamarCloudService
    @State private var saved = [ItamarSavedContact]()
    @State private var username = ""
    @State private var nickname = ""
    @State private var lookup = ""
    @State private var found: ItamarPhoneSearchResult?
    @State private var error = ""
    @State private var active = false

    private var invitation: URL {
        URL(string: "https://itamaros-web-emulator.onrender.com/downloads.html")!
    }

    var body: some View {
        Form {
            Section("My synced contacts") {
                if saved.isEmpty {
                    Text("No saved contacts yet. Search by username or an opt-in verified phone number.")
                        .foregroundStyle(.secondary)
                }
                ForEach(saved) { contact in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(contact.nickname.isEmpty ? contact.display_name : contact.nickname)
                            .font(.headline)
                        Text("@\(contact.username)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Add by username or scanned QR") {
                TextField("@username", text: $username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Optional nickname", text: $nickname)
                Button("Save contact to my account") {
                    Task { await add(username) }
                }.disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("A personal QR contains a username, not a private phone number.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Find an opted-in phone number") {
                TextField("+972501234567", text: $lookup)
                    .keyboardType(.phonePad)
                Button("Check for a verified account") {
                    Task {
                        do {
                            found = try await cloud.lookupPhone(lookup.trimmingCharacters(in:.whitespacesAndNewlines))
                            error = found == nil ? "No discoverable account found. You can invite this person instead." : ""
                        } catch { error = error.localizedDescription }
                    }
                }
                .disabled(!lookup.hasPrefix("+"))
                if let found {
                    Text("\(found.display_name) · @\(found.username)")
                    Button("Add this account") { Task { await add(found.username) } }
                } else if !lookup.isEmpty {
                    ShareLink(item: invitation, subject: Text("Try ItamarOS Connect"),
                              message: Text("Join me on ItamarOS Connect!")) {
                        Label("Invite using Messages, WhatsApp or another app", systemImage: "square.and.arrow.up")
                    }
                    Text("Invitations are shared only after you choose a recipient and confirm.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Only users who verified their own phone and opted in are searchable. Searches are limited.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if !error.isEmpty { Text(error).foregroundStyle(.red).font(.caption) }
        }
        .navigationTitle("Contacts")
        .task {
            if let initialUsername { username = initialUsername }
            await reload()
        }
        .refreshable { await reload() }
    }

    private func reload() async {
        do { saved = try await cloud.savedContacts() }
        catch { error = error.localizedDescription }
    }
    private func add(_ handle: String) async {
        do {
            try await cloud.addContact(username: handle, nickname: nickname)
            found = nil
            username = ""
            nickname = ""
            error = ""
            await reload()
        } catch { error = error.localizedDescription }
    }
}

struct ItamarContactRoute: Identifiable {
    let username: String
    var id: String { username }
}

struct ItamarMyContactQRView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let profile = cloud.profile {
                    Text(profile.display_name).font(.title2.bold())
                    Text("@\(profile.username)")
                    // A HTTPS link can be opened on devices without the app.
                    let url = URL(string: "https://itamaros-web-emulator.onrender.com/contact.html?username=\(profile.username)")!
                    if let qr = itamarQR(url.absoluteString) {
                        Image(uiImage: qr).interpolation(.none).resizable().scaledToFit()
                            .frame(width: 240, height: 240).padding(15)
                            .background(.white, in: RoundedRectangle(cornerRadius: 18))
                    }
                    ShareLink(item: url) {
                        Label("Share my contact QR link", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Text("Create a profile first to share a username QR.")
                }
                Text("The QR shares a public username only, never your telephone number or contact list.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }.navigationTitle("My QR")
    }
}

struct ItamarPhoneSettingsView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @State private var phone = ""
    @State private var otp = ""
    @State private var allowLookup = false
    @State private var status = ""

    var body: some View {
        Form {
            Section("Verify my phone (optional)") {
                TextField("+972501234567", text: $phone).keyboardType(.phonePad)
                Button("Send verification SMS") {
                    Task {
                        do {
                            try await cloud.setPhoneForVerification(phone.trimmingCharacters(in:.whitespacesAndNewlines))
                            status = "If SMS is enabled on the project, check your phone for a verification code."
                        } catch { status = error.localizedDescription }
                    }
                }
                .disabled(!phone.hasPrefix("+"))
                TextField("Verification code", text: $otp).keyboardType(.numberPad)
                Button("Verify my number") {
                    Task {
                        do {
                            try await cloud.verifyPhoneChange(phone: phone, otp: otp)
                            status = "Phone verified. You can choose whether others may find you."
                        } catch { status = error.localizedDescription }
                    }
                }.disabled(otp.isEmpty)
            }
            Section("Discoverability") {
                Toggle("Allow others to find me by my verified number", isOn: $allowLookup)
                Button("Save discoverability choice") {
                    Task {
                        do {
                            try await cloud.setPhoneDiscoverability(allowLookup)
                            status = allowLookup ? "Opt-in enabled. Only your verified number is searchable." : "Phone discovery disabled."
                        } catch { status = error.localizedDescription }
                    }
                }
            }
            Text("This uses your own Supabase Auth phone verification. Number discovery is off unless explicitly enabled. Do not use another person's number.")
                .font(.footnote).foregroundStyle(.secondary)
            if !status.isEmpty { Text(status).font(.footnote) }
        }
        .navigationTitle("Phone & privacy")
    }
}

struct ItamarCreateGroupView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var usernames = ""
    @State private var error = ""

    var body: some View {
        Form {
            Section("Group") {
                TextField("Group name", text: $title)
                TextField("Usernames separated by commas", text: $usernames, axis: .vertical)
                    .lineLimit(2...4)
                Text("Add 1–30 existing @usernames. Group members can post; the owner can rename and manage members.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Button("Create group") {
                Task {
                    do {
                        let names = usernames.split(separator: ",").map {
                            String($0).trimmingCharacters(in:.whitespacesAndNewlines)
                                .lowercased().replacingOccurrences(of:"@",with:"")
                        }.filter { !$0.isEmpty }
                        try await cloud.createGroup(title: title, usernames: names)
                        dismiss()
                    } catch { error = error.localizedDescription }
                }
            }
            .disabled(title.isEmpty || usernames.isEmpty)
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("New group")
        .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cancel") { dismiss() } } }
    }
}

struct ItamarGroupPollsView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    let room: UUID
    @State private var polls = [ItamarPoll]()
    @State private var totals = [UUID: [Int]]()
    @State private var question = ""
    @State private var options = "Yes\nNo"
    @State private var multiple = false
    @State private var error = ""

    var body: some View {
        Form {
            Section("Create poll") {
                TextField("Question", text: $question)
                TextField("Options (one per line)", text: $options, axis: .vertical)
                    .lineLimit(2...8)
                Toggle("Allow multiple answers", isOn:$multiple)
                Button("Publish poll") {
                    Task {
                        do {
                            let values = options.split(separator:"\n").map {
                                String($0).trimmingCharacters(in:.whitespacesAndNewlines)
                            }.filter { !$0.isEmpty }
                            try await cloud.createPoll(room:room, question:question, options:values, multiple:multiple)
                            question = ""
                            await refresh()
                        } catch { error = error.localizedDescription }
                    }
                }.disabled(question.isEmpty)
            }
            Section("Group polls") {
                ForEach(polls) { poll in
                    VStack(alignment:.leading,spacing:10) {
                        Text(poll.question).font(.headline)
                        ForEach(poll.options.indices,id:\.self) { i in
                            Button {
                                Task {
                                    do {
                                        try await cloud.vote(poll:poll.id,option:i)
                                        await refresh()
                                    } catch { error = error.localizedDescription }
                                }
                            } label: {
                                HStack {
                                    Text(poll.options[i])
                                    Spacer()
                                    Text("\(totals[poll.id]?[i] ?? 0) votes")
                                }
                            }.disabled(poll.closed)
                        }
                    }
                }
            }
            if !error.isEmpty { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("Group polls")
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private func refresh() async {
        do {
            let loaded = try await cloud.polls(in:room)
            var counts = [UUID: [Int]]()
            for poll in loaded {
                let votes = try await cloud.pollResults(pollID:poll.id)
                counts[poll.id] = poll.options.indices.map { i in
                    votes.filter { $0.option_index == i }.count
                }
            }
            polls = loaded; totals = counts
        } catch { error = error.localizedDescription }
    }
}

struct ItamarGroupRoute: Identifiable {
    let token: String
    var id: String { token }
}

struct ItamarGroupInfoView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    let room: ItamarCloudRoom
    @State private var title = ""
    @State private var details = ""
    @State private var photoPath: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var inviteToken: String?
    @State private var memberHandle = ""
    @State private var message = ""

    private var mine: Bool { cloud.userID == room.owner_id }
    private var shareURL: URL? {
        guard let inviteToken else { return nil }
        return URL(string:"https://itamaros-web-emulator.onrender.com/join.html?invite=\(inviteToken)")
    }

    var body: some View {
        Form {
            Section("Group identity") {
                if let photoURL=cloud.publicAvatarURL(photoPath) {
                    AsyncImage(url:photoURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { ProgressView() }
                    .frame(width:96,height:96).clipShape(Circle())
                } else {
                    Image(systemName:"person.3.fill")
                        .font(.largeTitle).foregroundStyle(.blue)
                }
                TextField("Group name (required)",text:$title)
                    .disabled(!mine)
                TextField("Description (optional)",text:$details,axis:.vertical)
                    .lineLimit(2...5).disabled(!mine)
                if mine {
                    PhotosPicker(selection:$selectedPhoto,matching:.images) {
                        Label("Choose group photo",systemImage:"camera")
                    }
                    .onChange(of:selectedPhoto) { _,photo in
                        guard let photo else { return }
                        Task {
                            do {
                                guard let data=try await photo.loadTransferable(type:Data.self),
                                      let image=UIImage(data:data),
                                      let jpeg=image.jpegData(compressionQuality:0.65) else {
                                    throw ItamarCloudError.badResponse("Unable to open image")
                                }
                                photoPath=try await cloud.uploadAvatarJPEG(jpeg,group:room.id)
                                try await cloud.updateGroupDetails(room:room.id,name:title,
                                                                   description:details,avatar:photoPath)
                            } catch { message=error.localizedDescription }
                        }
                    }
                    Button("Save group name and description") {
                        Task {
                            do {
                                try await cloud.updateGroupDetails(room:room.id,name:title,
                                                                   description:details,avatar:photoPath)
                                message="Group details saved"
                            } catch { message=error.localizedDescription }
                        }
                    }.disabled(title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                }
            }
            if mine {
                Section("Add members directly") {
                    TextField("Username",text:$memberHandle)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Add member") {
                        Task {
                            do {
                                try await cloud.manageGroup(room:room.id,operation:"add",username:memberHandle)
                                memberHandle=""
                                message="Member added"
                            } catch { message=error.localizedDescription }
                        }
                    }.disabled(memberHandle.isEmpty)
                }
                Section("Invite by message, link or QR") {
                    Button("Create 48-hour invitation") {
                        Task {
                            do {
                                inviteToken=try await cloud.groupInvite(room:room.id)
                                message="Invite link generated. Anyone with this link can request to join."
                            } catch { message=error.localizedDescription }
                        }
                    }
                    if let shareURL {
                        if let qr=itamarQR(shareURL.absoluteString) {
                            Image(uiImage:qr).interpolation(.none).resizable().scaledToFit()
                                .frame(width:210,height:210)
                        }
                        ShareLink(item:shareURL) {
                            Label("Share invitation by Messages, WhatsApp or other app",
                                  systemImage:"square.and.arrow.up")
                        }
                        Text("Expires after 48 hours. People join only after accepting the invitation.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if !message.isEmpty { Text(message).font(.caption) }
        }
        .navigationTitle("Group info")
        .onAppear {
            let current=cloud.rooms.first(where:{$0.id==room.id}) ?? room
            title=current.title
            details=current.description ?? ""
            photoPath=current.avatar_path
        }
    }
}

struct ItamarAcceptGroupInviteView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @Environment(\.dismiss) private var dismiss
    let token: String
    @State private var error = ""
    @State private var joined = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Group invitation") {
                    Text("Joining will share your public profile with the group's members.")
                    Text("You can decline. An invite link does not give anyone access to your phone number or private chats.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if !cloud.isSignedIn {
                        Text("Sign in to ItamarOS Connect before accepting.")
                        ItamarCloudLoginView()
                    } else {
                        Button("Accept and join group") {
                            Task {
                                do {
                                    try await cloud.acceptGroupInvite(code:token)
                                    joined=true
                                } catch { error=error.localizedDescription }
                            }
                        }.disabled(joined)
                        if joined {
                            Label("Joined group successfully",systemImage:"checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Join group")
            .toolbar { ToolbarItem(placement:.confirmationAction) {Button("Done"){dismiss()}} }
        }
    }
}

#endif
