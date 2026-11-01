#if os(iOS)
import SwiftUI
import GameController

// Original multiplayer prototypes; Crossy Road Castle assets/levels are not used.
private struct PartyPosition: Decodable { let x: Double; let y: Double }
private struct ItamarPartyState: Decodable {
    let code: String
    let game: String
    let host_id: UUID
    let player2: UUID?
    let player3: UUID?
    let player4: UUID?
    let status: String
    let board: String
    let turn_slot: Int
    let winner: String
    let your_choice: String
    let revealed_choices: [String]?
    let positions: [String:PartyPosition]
    let seed: Int
}

struct ItamarPartyGamesView: View {
    @EnvironmentObject private var cloud: ItamarCloudService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGame="connect_four"
    init(defaultGame:String="connect_four") {
        _selectedGame=State(initialValue:defaultGame)
    }
    @State private var match: ItamarPartyState?
    @State private var joinCode=""
    @State private var inviteUser=""
    @State private var status=""
    @State private var busy=false
    @State private var posX:CGFloat=48
    @State private var posY:CGFloat=430
    @State private var velocityY:CGFloat=0
    @State private var pressLeft=false
    @State private var pressRight=false
    @State private var pressJump=false
    @State private var landed=false
    @State private var lastPositionUpload=Date.distantPast
    private let gameOptions=[
        ("connect_four","Connect Four · 2 players"),
        ("rock_paper_scissors","Rock Paper Scissors · 2 players"),
        ("cloud_climb","Cloud Climb · up to 4 players")
    ]
    private let timer=Timer.publish(every:1.0/30.0,on:.main,in:.common).autoconnect()
    private var slot:Int {
        guard let match, let me=cloud.userID else {return 0}
        if match.host_id==me {return 1}
        if match.player2==me {return 2}
        if match.player3==me {return 3}
        if match.player4==me {return 4}
        return 0
    }
    private var playerCount:Int {
        guard let match else {return 0}
        return 1 + [match.player2,match.player3,match.player4].compactMap{$0}.count
    }
    private var myMark:String {slot==1 ? "X":"O"}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:16) {
                    Text("ItamarOS online rooms").font(.title2.bold())
                    if let match {
                        Text(match.game=="cloud_climb" ? "Cloud Climb" :
                            (match.game=="connect_four" ? "Connect Four":"Rock Paper Scissors"))
                            .font(.headline)
                        Text("Room: \(match.code)")
                            .font(.title3.monospaced().bold())
                            .textSelection(.enabled)
                        Text("\(playerCount) / \(match.game=="cloud_climb" ? 4 : 2) players")
                            .foregroundStyle(.secondary)
                        if match.game != "cloud_climb", match.status == "waiting" {
                            ShareLink(item:"Join my ItamarOS game with code \(match.code)") {
                                Label("Share room code",systemImage:"square.and.arrow.up")
                            }
                            HStack {
                                TextField("Invite @username",text:$inviteUser)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                Button("Chat invite"){Task{await sendInvite()}}
                                    .disabled(inviteUser.isEmpty || busy)
                            }
                        }
                        if match.game=="cloud_climb" {
                            Text("Code-only: invites and automatic sharing are disabled.")
                                .font(.footnote).foregroundStyle(.secondary)
                            cloudClimb
                        } else if match.status=="waiting" {
                            Text("Waiting for a second player…")
                        } else if match.game=="connect_four" {
                            connectFour
                        } else {
                            rockPaperScissors
                        }
                        Button("Leave room view") {
                            self.match=nil;joinCode="";resetMovement()
                        }.buttonStyle(.bordered)
                    } else {
                        Picker("Game",selection:$selectedGame) {
                            ForEach(gameOptions,id:\.0) { option in
                                Text(option.1).tag(option.0)
                            }
                        }.pickerStyle(.menu)
                        Button("Create room") {Task{await create()}}
                            .buttonStyle(.borderedProminent).disabled(busy)
                        TextField("Enter 10-character room code",text:$joinCode)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of:joinCode) {_,value in
                                joinCode=String(value.uppercased().filter{$0.isASCII && $0.isHexDigit}.prefix(10))
                            }
                        Button("Join room"){Task{await join()}}
                            .disabled(busy || joinCode.count != 10)
                    }
                    if busy {ProgressView()}
                    if !status.isEmpty {
                        Text(status).font(.footnote).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Text("Every player needs their own unique ItamarOS @username. Rooms expire after 12 hours.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding()
            }
            .navigationTitle("Online")
            .toolbar {ToolbarItem(placement:.topBarTrailing) {
                Button("Done"){dismiss()}
            }}
        }
        .task(id:match?.code) {
            while !Task.isCancelled,match != nil {
                try? await Task.sleep(for:.milliseconds(700))
                if Task.isCancelled {break}
                await refresh()
            }
        }
    }
    private var connectFour:some View {
        VStack(spacing:10){
            Text(match?.status=="finished" ?
                (match?.winner=="draw" ? "Draw!" :
                   (match?.winner==myMark ? "You won!":"Other player won!")) :
                (match?.turn_slot==slot ? "Your turn" : "Other player's turn"))
                .font(.headline)
            let board=Array(match?.board ?? String(repeating:"_",count:42))
            VStack(spacing:4) {
                ForEach(0..<6,id:\.self){row in
                    HStack(spacing:4) {
                        ForEach(0..<7,id:\.self){column in
                            let index=row*7+column
                            Button {
                                Task{await move(column:column)}
                            } label: {
                                Circle()
                                    .fill(board[index]=="X" ? Color.orange :
                                          (board[index]=="O" ? Color.cyan : Color.gray.opacity(0.15)))
                                    .frame(minWidth:22,minHeight:27)
                                    .frame(maxWidth:.infinity)
                            }
                            .disabled(busy || match?.status != "playing" || match?.turn_slot != slot ||
                                      board[column] != "_")
                        }
                    }
                }
            }
            .padding(9)
            .background(.blue.opacity(0.15),in:RoundedRectangle(cornerRadius:12))
        }
    }
    private var rockPaperScissors:some View {
        VStack(spacing:12) {
            Text(match?.status=="finished" ?
                (match?.winner=="draw" ? "Draw!" :
                  (match?.winner==myMark ? "You won!":"Other player won!")) :
                 (match?.your_choice=="" ? "Choose secretly":"Waiting for other player…"))
                .font(.headline)
            HStack(spacing:10){
                ForEach(["rock","paper","scissors"],id:\.self){choice in
                    Button(choice.capitalized){Task{await choose(choice)}}
                        .disabled(busy || match?.status != "playing" || match?.your_choice != "")
                }
            }
            if let revealed=match?.revealed_choices {
                Text("Player 1: \(revealed[0])  ·  Player 2: \(revealed[1])")
            }
        }
    }
    private func platforms(_ seed:Int)->[CGRect]{
        var value=UInt64(UInt32(truncatingIfNeeded:seed))
        func next()->CGFloat {
            value = value &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((value>>32)%1000)/1000
        }
        var items=[CGRect(x:0,y:472,width:400,height:20)]
        for row in 0..<6 {
            let x:CGFloat=16 + next()*205
            let y:CGFloat=405-CGFloat(row)*61
            items.append(CGRect(x:x,y:y,width:130+next()*40,height:11))
        }
        return items
    }
    private var cloudClimb:some View {
        VStack(spacing:12){
            Text(match?.status=="waiting" ? "Waiting for at least 2 players to start." :
                 "Climb together! This is an experimental co-op prototype.")
                .font(.footnote).foregroundStyle(.secondary)
            Canvas { ctx,size in
                let w=size.width,h=size.height
                ctx.fill(Path(CGRect(origin:.zero,size:size)),
                    with:.linearGradient(Gradient(colors:[.indigo.opacity(0.75),.cyan.opacity(0.35)]),
                                         startPoint:.zero,endPoint:CGPoint(x:w,y:h)))
                let sx=w/400,sy=h/500
                let stages=platforms(match?.seed ?? 0)
                for (i,platform) in stages.enumerated() {
                    let rect=CGRect(x:platform.minX*sx,y:platform.minY*sy,
                        width:platform.width*sx,height:platform.height*sy)
                    ctx.fill(Path(roundedRect:rect,cornerRadius:4),
                             with:.color(i==0 ? .mint : .white.opacity(0.9)))
                }
                for player in 1...4 {
                    guard let match else{break}
                    let p=match.positions["\(player)"]
                    if player != slot && p==nil {continue}
                    let x=player==slot ? posX : CGFloat(p!.x)*400/1024
                    let y=player==slot ? posY : CGFloat(p!.y)*500/2048
                    let tint:Color=[.orange,.pink,.mint,.yellow][player-1]
                    let avatar=CGRect(x:(x-12)*sx,y:(y-21)*sy,width:24*sx,height:24*sy)
                    ctx.fill(Path(roundedRect:avatar,cornerRadius:6),with:.color(tint))
                    ctx.draw(Text("P\(player)").font(.system(size:12,weight:.bold)),
                             at:CGPoint(x:x*sx,y:(y-29)*sy))
                }
            }
            .aspectRatio(4.0/5.0,contentMode:.fit)
            .frame(maxWidth:350)
            .clipShape(RoundedRectangle(cornerRadius:16))
            .onReceive(timer) { _ in tickClimb() }
            HStack(spacing:12) {
                steerButton("◀",left:true)
                steerButton("▶",left:false)
                Button("Jump") {pressJump=true}
                    .buttonStyle(.borderedProminent)
            }
            Text("Touch controls or a connected Xbox, PlayStation or Switch-compatible controller.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
    private func steerButton(_ label:String,left:Bool)->some View {
        Text(label).font(.title2)
            .padding(14).background(.thinMaterial,in:RoundedRectangle(cornerRadius:10))
            .gesture(DragGesture(minimumDistance:0).onChanged{_ in
                if left {pressLeft=true}else{pressRight=true}
            }.onEnded{_ in
                if left {pressLeft=false}else{pressRight=false}
            })
            .accessibilityLabel(left ? "Move left":"Move right")
    }
    private func tickClimb(){
        guard match?.game=="cloud_climb",slot>0 else {return}
        let pad=GCController.controllers().first?.extendedGamepad
        let horizontal=CGFloat(pad?.leftThumbstick.xAxis.value ?? 0)
        let xInput=(pressLeft ? -1.0:0.0)+(pressRight ? 1.0:0.0)+Double(horizontal)
        let jump=pressJump || (pad?.buttonA.isPressed ?? false)
        pressJump=false
        posX=min(388,max(12,posX+CGFloat(max(-1,min(1,xInput)))*3.2))
        if jump && landed {velocityY = -9;landed=false}
        let oldBottom=posY+3
        velocityY=min(10,velocityY+0.38)
        posY+=velocityY
        if velocityY>=0 {
            for platform in platforms(match?.seed ?? 0) {
                if posX+11>platform.minX && posX-11<platform.maxX &&
                  oldBottom<=platform.minY && posY+3>=platform.minY {
                    posY=platform.minY-3
                    velocityY=0
                    landed=true
                    break
                }
            }
        }
        if posY>495 {posX=48;posY=430;velocityY=0;landed=true}
        if Date().timeIntervalSince(lastPositionUpload)>0.6,let code=match?.code{
            lastPositionUpload=Date()
            let x=Double(posX*1024/400),y=Double(posY*2048/500)
            Task { _=try? await cloud.request("/rest/v1/rpc/itamar_party_position",method:"POST",
                     data:["p_code":code,"p_x":x,"p_y":y]) }
        }
    }
    private func resetMovement(){
        posX=48;posY=430;velocityY=0;landed=true
        pressLeft=false;pressRight=false;pressJump=false
    }
    private func api(_ tool:String,_ payload:[String:Any]) async throws -> ItamarPartyState {
        let data=try await cloud.request("/rest/v1/rpc/"+tool,method:"POST",data:payload)
        return try JSONDecoder().decode(ItamarPartyState.self,from:data)
    }
    private func create() async {
        busy=true;defer{busy=false}
        do{match=try await api("itamar_party_create",["p_game":selectedGame]);status="";resetMovement()}
        catch{status=error.localizedDescription}
    }
    private func join() async {
        busy=true;defer{busy=false}
        do{match=try await api("itamar_party_join",["p_code":joinCode]);status="";resetMovement()}
        catch{status=error.localizedDescription}
    }
    private func refresh() async {
        guard let code=match?.code else{return}
        do{match=try await api("itamar_party_state",["p_code":code])}
        catch{status=error.localizedDescription}
    }
    private func move(column:Int) async {
        guard let code=match?.code else{return}
        busy=true;defer{busy=false}
        do{match=try await api("itamar_party_move",
            ["p_code":code,"p_column":column]);status=""}
        catch{status=error.localizedDescription}
    }
    private func choose(_ choice:String) async {
        guard let code=match?.code else{return}
        busy=true;defer{busy=false}
        do{match=try await api("itamar_party_move",
            ["p_code":code,"p_choice":choice]);status=""}
        catch{status=error.localizedDescription}
    }
    private func sendInvite() async {
        guard let code=match?.code else{return}
        busy=true;defer{busy=false}
        do{
            _=try await cloud.request("/rest/v1/rpc/itamar_party_invite",method:"POST",
                                      data:["p_code":code,"p_username":inviteUser])
            status="Invitation sent in a private chat"
            inviteUser=""
        }catch{status=error.localizedDescription}
    }
}
#endif
