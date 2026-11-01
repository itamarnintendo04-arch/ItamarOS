#if os(iOS)
import SwiftUI

private struct ItamarOnlineMatch: Decodable {
    let id: UUID
    let code: String
    let host_id: UUID
    let guest_id: UUID?
    let board: String
    let turn: String
    let winner: String
    let status: String
}

struct OnlineTicTacToeView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @Environment(\.dismiss) private var dismiss
    @State private var match: ItamarOnlineMatch?
    @State private var code = ""
    @State private var inviteUsername = ""
    @State private var feedback = ""
    @State private var busy = false

    private var mySymbol: String {
        guard let match else { return "" }
        return cloud.userID == match.host_id ? "X" : "O"
    }
    private var myTurn: Bool {
        match?.status == "playing" && match?.turn == mySymbol
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Text("Online Tic-Tac-Toe").font(.title2.bold())
                    Text("Create a room, share the code, and take turns from two different devices.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if let match {
                        Text("Room code: \(match.code)")
                            .font(.title3.monospaced().bold())
                            .textSelection(.enabled)
                        ShareLink(item: "Join my ItamarOS Tic-Tac-Toe game! Open Games → Online match and enter code \(match.code)") {
                            Label("Share code or invitation", systemImage:"square.and.arrow.up")
                        }
                        if match.status == "waiting" {
                            Text("Waiting for player two…").foregroundStyle(.secondary)
                            HStack {
                                TextField("Invite @username in Chat", text: $inviteUsername)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                Button("Invite") {
                                    Task { await invite() }
                                }.disabled(inviteUsername.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || busy)
                            }
                        } else {
                            Text(match.status == "finished" ?
                                (match.winner == "draw" ? "Draw!" :
                                    (match.winner == mySymbol ? "You won!" : "Other player won!")) :
                                    (myTurn ? "Your turn (\(mySymbol))" : "Other player's turn"))
                                .font(.headline)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(),spacing:8),count:3),spacing:8) {
                                ForEach(0..<9,id:\.self) { position in
                                    let piece = Array(match.board)[position]
                                    Button {
                                        Task { await move(position) }
                                    } label: {
                                        Text(piece == "_" ? " " : String(piece))
                                            .font(.system(size: 42,weight:.bold))
                                            .frame(maxWidth:.infinity,minHeight:76)
                                            .background(.thinMaterial,in:RoundedRectangle(cornerRadius:12))
                                    }
                                    .disabled(!myTurn || busy || piece != "_")
                                }
                            }
                            .frame(maxWidth:360)
                        }
                        Button("Leave match view") { self.match = nil; code = "" }
                            .buttonStyle(.bordered)
                    } else {
                        Button("Create online game") { Task { await create() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(busy)
                        HStack {
                            TextField("10-character room code",text:$code)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                                .onChange(of:code) { _,v in
                                    code=String(v.uppercased().filter { $0.isASCII && $0.isHexDigit }.prefix(10))
                                }
                            Button("Join") { Task { await join() } }
                                .disabled(code.count != 10 || busy)
                        }
                    }
                    if !feedback.isEmpty {
                        Text(feedback).font(.footnote).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Text("A username and verified account are required. Codes expire after 24 hours.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Online match")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .task(id: match?.code) {
            while !Task.isCancelled, match != nil {
                try? await Task.sleep(for:.seconds(2))
                if Task.isCancelled { break }
                await refresh()
            }
        }
    }

    private func call(_ name: String, payload: [String: Any] = [:]) async throws -> ItamarOnlineMatch {
        let response=try await cloud.request("/rest/v1/rpc/"+name,method:"POST",data:payload)
        return try JSONDecoder().decode(ItamarOnlineMatch.self,from:response)
    }
    private func create() async {
        busy=true; defer { busy=false }
        do { match=try await call("itamar_game_create"); feedback="" }
        catch { feedback=error.localizedDescription }
    }
    private func join() async {
        busy=true; defer { busy=false }
        do { match=try await call("itamar_game_join",payload:["p_code":code]); feedback="" }
        catch { feedback=error.localizedDescription }
    }
    private func move(_ index: Int) async {
        guard let code=match?.code else { return }
        busy=true; defer { busy=false }
        do { match=try await call("itamar_game_move",payload:["p_code":code,"p_position":index]);feedback="" }
        catch { feedback=error.localizedDescription; await refresh() }
    }
    private func invite() async {
        guard let code=match?.code else { return }
        busy=true; defer { busy=false }
        do {
            _=try await cloud.request("/rest/v1/rpc/itamar_game_invite",method:"POST",
                                     data:["p_code":code,"p_username":inviteUsername])
            feedback="Invitation sent in a private ItamarOS chat."
            inviteUsername=""
        } catch { feedback=error.localizedDescription }
    }
    private func refresh() async {
        guard let code=match?.code else { return }
        do { match=try await call("itamar_game_get",payload:["p_code":code]) }
        catch { feedback=error.localizedDescription }
    }
}
#endif
