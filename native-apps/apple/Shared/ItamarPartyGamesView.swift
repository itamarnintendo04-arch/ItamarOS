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
    // Local account progress; remote room positions are not progression sync.
    @State private var climbLoaded=false
    @State private var climbLevel=1
    @State private var climbCoins=0
    @State private var climbHearts=3
    @State private var climbBossHealth=3
    @State private var climbShopDue=0
    @State private var climbPaused=false
    @State private var climbGameOver=false
    @State private var climbMessage=""
    @State private var lastBossStrike=Date.distantPast
    @State private var climbControllerConnected=false
    @State private var climbPreviousPauseButton=false
    @State private var climbSettingsPresented=false
    @AppStorage("cloudClimb.autoHideControls") private var climbAutoHideControls=true
    @AppStorage("cloudClimb.showTips") private var climbShowTips=true
    @AppStorage("cloudClimb.twilightSky") private var climbTwilightSky=false
    @State private var climbCloudReady=false
    @State private var climbRevision:Int64=0
    @State private var climbCloudSaving=false
    @State private var climbPendingUpload=false
    @State private var climbSyncStatus="Local save"
    private var climbSaveKey:String {
        "itamaros_cloud_climb_v1_" + (cloud.userID?.uuidString ?? "guest")
    }
    private var climbStageSeed:Int {(match?.seed ?? 0) &+ (climbLevel &* 2039)}
    private var climbIsBoss:Bool {climbLevel % 30 == 0}
    private var climbShowTouch:Bool {!climbControllerConnected || !climbAutoHideControls}
    private var climbBossX:CGFloat {platforms(climbStageSeed).last?.midX ?? 200}
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
                            saveClimb();self.match=nil;joinCode="";resetMovement()
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
                Button("Done"){saveClimb();dismiss()}
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
        VStack(spacing:14){
            Text("☁️ CLOUD CLIMB")
                .font(.title.bold()).foregroundStyle(.white)
                .frame(maxWidth:.infinity,alignment:.leading)
            if climbShowTips {
                Text(match?.status=="waiting" ? "Waiting for another player." :
                     "Climb together! Explore the sky in this original platformer.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.88))
            }
            HStack {
                Text("LEVEL \(climbLevel)").font(.headline).foregroundStyle(.yellow)
                Spacer()
                Text("❤️ \(climbHearts)/3  🪙 \(climbCoins)")
                    .font(.subheadline.bold()).foregroundStyle(.white)
            }
            if climbShowTips {
                Text(climbIsBoss ? "Boss level: 3 hits!" : "Reach the highest platform to finish the level.")
                    .font(.caption).foregroundStyle(.white.opacity(0.85))
            }
            HStack {
                Button("⚙ Settings") {climbSettingsPresented=true}
                    .buttonStyle(.bordered)
                Button(climbPaused ? "Resume" : "Pause") {
                    climbPaused.toggle()
                    pressLeft=false;pressRight=false;pressJump=false
                }.disabled(climbGameOver || climbShopDue != 0)
                Button("Exit to menu") {
                    saveClimb();match=nil;joinCode="";resetMovement()
                }
            }.buttonStyle(.bordered)
            if climbGameOver {
                Text("Game over · Retry level \(climbLevel)")
                Button("Try Again") {
                    climbHearts=3;climbBossHealth=3;climbGameOver=false
                    resetMovement();saveClimb()
                }.buttonStyle(.borderedProminent)
            } else if climbShopDue != 0 {
                Text("Level \(climbShopDue) cleared! Buy a missing heart for 100 coins?")
                HStack {
                    Button("Buy heart · 100 🪙") {
                        guard climbCoins>=100 && climbHearts<3 else{return}
                        climbCoins-=100;climbHearts+=1;climbShopDue=0
                        climbMessage="1 heart restored";saveClimb()
                    }.disabled(climbCoins<100 || climbHearts>=3)
                    Button("Skip") {climbShopDue=0;saveClimb()}
                }.buttonStyle(.bordered)
            } else if climbPaused {
                Text("Paused. Your progress is saved.")
                Button("Resume") {climbPaused=false}
            }
            Canvas { ctx,size in
                let w=size.width,h=size.height
                ctx.fill(Path(CGRect(origin:.zero,size:size)),
                    with:.linearGradient(Gradient(colors:
                        climbTwilightSky ? [.purple.opacity(0.95),.indigo.opacity(0.85)] :
                                          [.blue.opacity(0.9),.cyan.opacity(0.65)]),
                        startPoint:.zero,endPoint:CGPoint(x:w,y:h)))
                for i in 0..<16 {
                    let x=CGFloat((i*127+31)%390)/400*w
                    let y=CGFloat((i*83+47)%420)/500*h
                    ctx.fill(Path(ellipseIn:CGRect(x:x,y:y,width:4,height:4)),
                        with:.color(.white.opacity(climbTwilightSky ? 0.7:0.38)))
                }
                let sx=w/400,sy=h/500
                let stages=platforms(climbStageSeed)
                for (i,platform) in stages.enumerated() {
                    let rect=CGRect(x:platform.minX*sx,y:platform.minY*sy,
                        width:platform.width*sx,height:platform.height*sy)
                    ctx.fill(Path(roundedRect:rect,cornerRadius:4),
                             with:.color(i==0 ? .mint : .white.opacity(0.9)))
                }
                if climbIsBoss {
                    let rect=CGRect(x:(climbBossX-22)*sx,y:43*sy,width:44*sx,height:44*sy)
                    ctx.fill(Path(ellipseIn:rect),with:.color(.purple))
                    ctx.draw(Text("★").font(.system(size:24,weight:.bold)),
                             at:CGPoint(x:climbBossX*sx,y:65*sy))
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
            if climbShowTouch && climbIsBoss && !climbPaused && !climbGameOver && climbShopDue==0 {
                Button("Strike boss · \(climbBossHealth)/3") {strikeClimbBoss()}
                    .disabled(!landed || posY>=115 || abs(posX-climbBossX)>=85)
                    .buttonStyle(.borderedProminent)
            }
            if climbShowTouch && !climbPaused && !climbGameOver && climbShopDue==0 {
                HStack(spacing:12) {
                steerButton("◀",left:true)
                steerButton("▶",left:false)
                Button("Jump") {pressJump=true}
                    .buttonStyle(.borderedProminent)
            }
            }
            if !climbMessage.isEmpty {
                Text(climbMessage).font(.footnote).foregroundStyle(.secondary)
            }
            Text(climbSyncStatus)
                .font(.caption).foregroundStyle(.yellow)
            Text(climbControllerConnected ?
                 "🎮 Controller connected · A: Jump · X: Attack · Menu: Pause" :
                 "Touch controls · Connect a controller to hide them automatically.")
                .font(.caption).foregroundStyle(.white.opacity(0.87))
        }
        .padding(16)
        .background(
            LinearGradient(colors:climbTwilightSky ?
                [Color(red:0.12,green:0.08,blue:0.32),.purple] :
                [Color(red:0.10,green:0.23,blue:0.52),.teal],
                startPoint:.topLeading,endPoint:.bottomTrailing),
            in:RoundedRectangle(cornerRadius:24)
        )
        .sheet(isPresented:$climbSettingsPresented) {climbSettings}
    }
    private var climbSettings:some View {
        NavigationStack {
            Form {
                Section("Controls") {
                    Toggle("Auto-hide touch controls",isOn:$climbAutoHideControls)
                    Toggle("Show control tips",isOn:$climbShowTips)
                    Text(climbControllerConnected ? "Controller connected" : "No controller connected")
                }
                Section("Appearance") {
                    Toggle("Twilight sky theme",isOn:$climbTwilightSky)
                }
                Section("Account & Progress") {
                    Text("Sign in with your verified phone number in ItamarOS Connect.")
                    Text(climbSyncStatus)
                    Text("Using the same verified phone number on another device signs you into the same Supabase account.")
                }
            }
            .navigationTitle("Cloud Climb Settings")
            .toolbar {ToolbarItem(placement:.confirmationAction) {
                Button("Done"){climbSettingsPresented=false}
            }}
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
        guard match?.game=="cloud_climb" else{return}
        let controllers=GCController.controllers()
        let connected=controllers.contains {$0.extendedGamepad != nil}
        if climbControllerConnected != connected {climbControllerConnected=connected}
        let pad=controllers.first(where:{$0.extendedGamepad != nil})?.extendedGamepad
        let menuPressed=pad?.buttonMenu?.isPressed ?? false
        if menuPressed && !climbPreviousPauseButton && !climbGameOver && climbShopDue==0 {
            climbPaused.toggle()
            pressLeft=false;pressRight=false;pressJump=false
        }
        climbPreviousPauseButton=menuPressed
        guard slot>0,!climbPaused,!climbGameOver,climbShopDue==0 else{return}
        if pad?.buttonX.isPressed ?? false {strikeClimbBoss()}
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
            landed=false
            for platform in platforms(climbStageSeed) {
                if posX+11>platform.minX && posX-11<platform.maxX &&
                  oldBottom<=platform.minY && posY+3>=platform.minY {
                    posY=platform.minY-3
                    velocityY=0
                    landed=true
                    break
                }
            }
        }
        if posY>495 {loseClimbHeart();return}
        if landed && posY<110 && !climbIsBoss {finishClimbLevel();return}
        if Date().timeIntervalSince(lastPositionUpload)>0.6,let code=match?.code{
            lastPositionUpload=Date()
            let x=Double(posX*1024/400),y=Double(posY*2048/500)
            Task { _=try? await cloud.request("/rest/v1/rpc/itamar_party_position",method:"POST",
                     data:["p_code":code,"p_x":x,"p_y":y]) }
        }
    }
    private func saveClimb(){
        guard climbLoaded else{return}
        UserDefaults.standard.set([
            "level":climbLevel,"coins":climbCoins,"hearts":climbHearts,
            "bossHealth":climbBossHealth,"shopDue":climbShopDue,
            "gameOver":climbGameOver
        ] as [String:Any],forKey:climbSaveKey)
        if climbCloudReady {
            climbPendingUpload=true
            Task {await uploadClimb()}
        }
    }
    private func loadClimb(){
        climbLoaded=false
        climbCloudReady=false
        climbRevision=0
        let saved=UserDefaults.standard.dictionary(forKey:climbSaveKey) ?? [:]
        climbLevel=max(1,saved["level"] as? Int ?? 1)
        climbCoins=max(0,saved["coins"] as? Int ?? 0)
        climbHearts=min(3,max(0,saved["hearts"] as? Int ?? 3))
        climbBossHealth=min(3,max(1,saved["bossHealth"] as? Int ?? 3))
        climbShopDue=max(0,saved["shopDue"] as? Int ?? 0)
        climbGameOver=(saved["gameOver"] as? Bool ?? false) || climbHearts==0
        climbPaused=false;climbMessage="";climbLoaded=true
        resetMovement()
    }
    @MainActor private func loadCloudClimb() async {
        guard cloud.isSignedIn else {
            climbSyncStatus="Local save · Sign in with verified SMS to sync"
            return
        }
        climbCloudReady=false
        do {
            let raw=try await cloud.request("/rest/v1/rpc/itamar_cloud_climb_state",
                                            method:"POST",data:[:])
            guard let state=try JSONSerialization.jsonObject(with:raw) as? [String:Any] else {
                climbSyncStatus="Local save · Cloud response unavailable"
                return
            }
            climbRevision=(state["revision"] as? NSNumber)?.int64Value ?? 0
            if state["exists"] as? Bool == true {
                climbLevel=max(1,state["level"] as? Int ?? 1)
                climbCoins=max(0,state["coins"] as? Int ?? 0)
                climbHearts=min(3,max(0,state["hearts"] as? Int ?? 3))
                climbBossHealth=min(3,max(1,state["boss_health"] as? Int ?? 3))
                climbShopDue=max(0,state["shop_due"] as? Int ?? 0)
                climbGameOver=(state["game_over"] as? Bool ?? false) || climbHearts==0
                resetMovement()
            }
            climbSyncStatus="Cloud save connected · Same verified number, same account"
            climbCloudReady=true
            if state["exists"] as? Bool != true {saveClimb()}
            else {UserDefaults.standard.set([
                "level":climbLevel,"coins":climbCoins,"hearts":climbHearts,
                "bossHealth":climbBossHealth,"shopDue":climbShopDue,
                "gameOver":climbGameOver
            ] as [String:Any],forKey:climbSaveKey)}
        }catch {
            climbSyncStatus="Local save · Cloud sync unavailable"
        }
    }
    @MainActor private func uploadClimb() async {
        guard !climbCloudSaving && climbCloudReady else{return}
        climbCloudSaving=true
        defer {climbCloudSaving=false}
        while climbCloudReady && climbPendingUpload {
            climbPendingUpload=false
            do {
                let raw=try await cloud.request("/rest/v1/rpc/itamar_cloud_climb_save",
                    method:"POST",data:[
                        "p_level":climbLevel,"p_coins":climbCoins,"p_hearts":climbHearts,
                        "p_boss_health":climbBossHealth,"p_shop_due":climbShopDue,
                        "p_game_over":climbGameOver,"p_revision":climbRevision])
                guard let obj=try JSONSerialization.jsonObject(with:raw) as? [String:Any] else {
                    climbSyncStatus="Local save · Unable to read sync response"
                    break
                }
                if obj["saved"] as? Bool == true {
                    climbRevision=(obj["revision"] as? NSNumber)?.int64Value ?? climbRevision
                    climbSyncStatus="Cloud progress saved"
                }else{
                    climbPendingUpload=false
                    climbCloudReady=false
                    climbSyncStatus="Newer progress on another device · Reloading"
                    await loadCloudClimb()
                }
            }catch{
                climbSyncStatus="Local save · Cloud upload will retry"
                break
            }
        }
    }
    private func finishClimbLevel(){
        let completed=climbLevel
        climbCoins+=10;climbLevel+=1;climbBossHealth=3
        climbShopDue=(completed % 10 == 0 && climbHearts<3) ? completed : 0
        climbMessage="Level \(completed) complete! +10 coins."
        resetMovement();saveClimb()
    }
    private func loseClimbHeart(){
        climbHearts=max(0,climbHearts-1)
        climbMessage="You fell. \(climbHearts) hearts remaining."
        if climbHearts==0 {climbGameOver=true}
        resetMovement();saveClimb()
    }
    private func strikeClimbBoss(){
        guard climbIsBoss,!climbPaused,!climbGameOver,climbShopDue==0,
              landed,posY<115,abs(posX-climbBossX)<85,
              Date().timeIntervalSince(lastBossStrike)>=0.9 else{return}
        lastBossStrike=Date()
        if climbBossHealth==1 {finishClimbLevel()}
        else {
            climbBossHealth-=1
            climbMessage="Boss hit! \(climbBossHealth) hits left."
            saveClimb()
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
        do{match=try await api("itamar_party_create",["p_game":selectedGame]);status="";loadClimb();await loadCloudClimb()}
        catch{status=error.localizedDescription}
    }
    private func join() async {
        busy=true;defer{busy=false}
        do{match=try await api("itamar_party_join",["p_code":joinCode]);status="";loadClimb();await loadCloudClimb()}
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
