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
    @State private var climbWorld=1
    @State private var climbWorlds:Set<Int>=[1]
    @State private var climbBlueCubes:Set<String>=[]
    @State private var climbColoredBosses:Set<Int>=[]
    @State private var climbCharacters:Set<String>=[]
    @State private var climbEquippedHero="starter"
    @State private var climbCharacterOrbOpen=false
    @State private var climbCharacterBusy=false
    @State private var climbCharacterNotice="Surprise character · 500 earned coins"
    @State private var climbDoorBusy=false
    @State private var climbSlashInput=""
    @State private var climbSlashReply="Type /help for commands"
    @State private var climbChatMessages:[String]=["Game: Welcome to Cloud Climb! Type /help."]
    @State private var climbChatUndo:(world:Int,hero:String,twilight:Bool,auto:Bool,tips:Bool,paused:Bool)?
    @State private var climbCancelPicker=false
    @State private var climbSlot=1
    @State private var climbSlotNames:[String]=["My Game 1","My Game 2","My Game 3"]
    @State private var climbRenameInput=""
    private var climbSaveKey:String {
        "itamaros_cloud_climb_v1_" + (cloud.userID?.uuidString ?? "guest") + "_save_\(climbSlot)"
    }
    private var climbSlotNameKey:String {"itamaros_cloud_climb_names_\(cloud.userID?.uuidString ?? "guest")"}
    private func storeClimbNames(){
        UserDefaults.standard.set(climbSlotNames,forKey:climbSlotNameKey)
    }
    private func switchClimbSlot(_ chosen:Int){
        guard (1...3).contains(chosen),chosen != climbSlot,!climbCloudSaving else{return}
        saveClimb()
        climbSlot=chosen
        climbChatUndo=nil
        climbChatMessages=["Game: You selected \(climbSlotNames[chosen-1]). Type /help."]
        loadClimb()
        Task {await loadCloudClimb()}
    }
    private func renameClimbSlot(){
        let clean=String(climbRenameInput.trimmingCharacters(in:.whitespacesAndNewlines).prefix(32))
        guard !clean.isEmpty else{return}
        climbSlotNames[climbSlot-1]=clean
        storeClimbNames()
        saveClimb()
    }
    private var climbGameSnapshot:[String:Any] {
        ["level":climbLevel,"coins":climbCoins,"hearts":climbHearts,
         "boss_health":climbBossHealth,"shop_due":climbShopDue,
         "game_over":climbGameOver,"selected_world":climbWorld,
         "equipped_hero":climbEquippedHero,
         "twilight_sky":climbTwilightSky,
         "auto_hide_controls":climbAutoHideControls,
         "show_tips":climbShowTips,
         "worlds":climbWorlds.sorted(),
         "blue_cubes":climbBlueCubes.sorted(),
         "colored_bosses":climbColoredBosses.sorted(),
         "characters":climbCharacters.sorted()]
    }
    private func showClimbCancelOptions(){
        climbCancelPicker=true
    }
    private func cancelClimbVisualChanges(){
        climbTwilightSky=false
        climbAutoHideControls=true
        climbShowTips=true
        climbEquippedHero="starter"
        climbPaused=false
        climbChatUndo=nil
        saveClimbPreferences()
        climbChatMessages.append("Game: Visual settings reset. Your saves and achievements are safe.")
        if climbChatMessages.count>12{climbChatMessages.removeFirst(climbChatMessages.count-12)}
    }
    private var climbStageSeed:Int {(match?.seed ?? 0) &+ (climbLevel &* 2039) &+ (climbWorld &* 1009)}
    private var climbKeyCount:Int {max(0,(climbLevel-1)/100-(climbWorlds.count-1))}
    private var climbSecretAvailable:Bool {climbColoredBosses.count==10}
    private var climbDoors:[Int] {
        guard (1...10).contains(climbWorld) else{return []}
        return (1...5).filter{!climbBlueCubes.contains("\(climbWorld):\($0)")}
    }
    private var climbNearDoor:Int? {
        let stages=platforms(climbStageSeed)
        return climbDoors.first {
            let rect=stages[$0]
            return abs(posX-rect.midX)<60 && abs(posY-(rect.minY-5))<60
        }
    }
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
            Text("World \(climbWorld) · 🔑 \(climbKeyCount) · 💙 \(climbBlueCubes.count)/50 · 🌈 \(climbColoredBosses.count)/10")
                .font(.caption.bold()).foregroundStyle(.white)
            ScrollView(.horizontal,showsIndicators:false){
                HStack(spacing:7) {
                    ForEach(1...11,id:\.self) { world in
                        let open=climbWorlds.contains(world) ||
                            (world==11 && climbSecretAvailable)
                        Button(world==11 ? "SECRET" : open ? "World \(world)" : "🔒 \(world)") {
                            if open {
                                climbWorld=world;resetMovement();saveClimb()
                            } else if world <= 10 && climbKeyCount>0 {
                                Task {await unlockClimbWorld(world)}
                            }
                        }
                        .disabled(!open && (climbKeyCount<1 || !climbCloudReady))
                        .buttonStyle(.bordered)
                    }
                }
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
                Text(climbShopDue % 30 == 0 ?
                    "Before Boss Level \(climbShopDue): buy a missing heart for 100 coins?" :
                    "Heart Shop · Restore one missing heart for 100 coins?")
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
                if (1...10).contains(climbWorld) {
                    for door in climbDoors {
                        let plat=stages[door]
                        let rect=CGRect(x:(plat.midX-12)*sx,y:(plat.minY-37)*sy,
                                        width:24*sx,height:37*sy)
                        ctx.fill(Path(roundedRect:rect,cornerRadius:7),
                            with:.color(Color(red:0.09,green:0.34,blue:0.85)))
                        ctx.fill(Path(ellipseIn:CGRect(x:(plat.midX+5)*sx,
                             y:(plat.minY-20)*sy,width:6*sx,height:6*sy)),
                            with:.color(.cyan))
                    }
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
                    if player==slot {
                        CloudClimbHeroes.draw(ctx,
                            hero:CloudClimbHeroes.unlocked(climbEquippedHero,owned:climbCharacters)
                                ? climbEquippedHero : "starter",
                            x:x,y:y,sx:sx,sy:sy)
                    } else {
                        let avatar=CGRect(x:(x-12)*sx,y:(y-21)*sy,width:24*sx,height:24*sy)
                        ctx.fill(Path(roundedRect:avatar,cornerRadius:6),with:.color(tint))
                    }
                    ctx.draw(Text("P\(player)").font(.system(size:12,weight:.bold)),
                             at:CGPoint(x:x*sx,y:(y-29)*sy))
                }
            }
            .aspectRatio(4.0/5.0,contentMode:.fit)
            .frame(maxWidth:350)
            .clipShape(RoundedRectangle(cornerRadius:16))
            .onReceive(timer) { _ in tickClimb() }
            if let door=climbNearDoor,!climbPaused,!climbGameOver,climbShopDue==0 {
                Button("🚪 Enter Blue Door \(door)") {
                    Task {await enterClimbBlueDoor(door)}
                }.disabled(climbDoorBusy).buttonStyle(.borderedProminent)
            }
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
                Text(climbMessage).font(.footnote).foregroundStyle(.white)
            }
            CloudClimbHeroPicker(owned:climbCharacters,
                selected:Binding(
                    get:{climbEquippedHero},
                    set:{ value in
                        guard CloudClimbHeroes.unlocked(value,owned:climbCharacters) else{return}
                        climbEquippedHero=value
                        UserDefaults.standard.set(value,forKey:climbSaveKey+".hero")
                        saveClimbPreferences()
                    }))
            Button("🔮 Character Orb · \(climbCharacters.count) characters") {
                climbCharacterOrbOpen=true
            }
            .buttonStyle(.borderedProminent)
            VStack(alignment:.leading,spacing:8) {
                Text("☁️ My Games · Three independent saves").font(.headline).foregroundStyle(.white)
                HStack {
                    ForEach(1...3,id:\.self){num in
                        Button(climbSlotNames[num-1]){
                            switchClimbSlot(num)
                        }
                        .buttonStyle(num==climbSlot ? .borderedProminent : .bordered)
                        .disabled(climbCloudSaving)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                }
                TextField("Rename this game",text:$climbRenameInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit{renameClimbSlot()}
                Button("Save game name"){renameClimbSlot()}
                    .disabled(climbRenameInput.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                Text("Progress from one game is never copied into another.")
                    .font(.caption).foregroundStyle(.white.opacity(0.9))
            }
            VStack(alignment:.leading,spacing:8) {
                HStack {
                    Text("💬 Game Chat · \(climbSlotNames[climbSlot-1])")
                    Spacer()
                    Button("Cancel…"){showClimbCancelOptions()}
                }
.font(.subheadline.bold()).foregroundStyle(.white)
                ForEach(climbChatMessages.indices,id:\.self){index in
                    Text(climbChatMessages[index])
                        .font(.caption).foregroundStyle(.white)
                        .frame(maxWidth:.infinity,alignment:.leading)
                }
                HStack {
                    TextField("Message game: /help, /undo…",text:$climbSlashInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .onSubmit{runClimbCommand()}
                    Button("Send") {runClimbCommand()}
                        .disabled(climbSlashInput.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                }
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
        .confirmationDialog("Choose what to cancel",isPresented:$climbCancelPicker,titleVisibility:.visible){
            Button("Undo Last Chat Command") {
                climbSlashInput="/undo";runClimbCommand()
            }
            Button("Reset Theme") {
                climbTwilightSky=false;saveClimbPreferences()
            }
            Button("Reset Hero") {
                climbEquippedHero="starter";saveClimbPreferences()
            }
            Button("Cancel All Changes") {cancelClimbVisualChanges()}
            Button("Keep Changes",role:.cancel){}
        } message: {
            Text("Cancel All resets visual settings, tips, controls and pause. Saved levels, currencies and rewards are never deleted.")
        }
        .alert("🔮 Character Orb",isPresented:$climbCharacterOrbOpen) {
            Button("Unlock for 500 Coins") {
                Task {await buyClimbCharacter()}
            }.disabled(climbCoins<500 || climbCharacterBusy)
            Button("Close",role:.cancel){}
        } message: {
            Text("Random NEW character for 500 earned game coins. No real-money purchases.\n"+climbCharacterNotice)
        }
    }
    private var climbSettings:some View {
        NavigationStack {
            Form {
                Section("Controls") {
                    Toggle("Auto-hide touch controls",isOn:Binding(
                        get:{climbAutoHideControls},
                        set:{climbAutoHideControls=$0;saveClimbPreferences()}
                    ))
                    Toggle("Show control tips",isOn:Binding(
                        get:{climbShowTips},
                        set:{climbShowTips=$0;saveClimbPreferences()}
                    ))
                    Text(climbControllerConnected ? "Controller connected" : "No controller connected")
                }
                Section("Appearance") {
                    Toggle("Twilight sky theme",isOn:Binding(
                        get:{climbTwilightSky},
                        set:{climbTwilightSky=$0;saveClimbPreferences()}
                    ))
                }
                Section("Account & Progress") {
                    Text("Your game is tied to your authenticated ItamarOS account.")
                    Text(climbSyncStatus)
                    Text("Levels, rewards and game preferences sync across signed-in devices. Offline demo saves stay local.")
                }
            }
            .navigationTitle("Cloud Climb Settings")
            .toolbar {ToolbarItem(placement:.confirmationAction) {
                Button("Done"){climbSettingsPresented=false}
            }}
        }
    }

    @MainActor private func loadClimbRewards() async {
        guard climbCloudReady,climbSlot==1 else{return}
        do {
            let data=try await cloud.request("/rest/v1/rpc/itamar_climb_rewards_state",
                                             method:"POST",data:[:])
            guard let obj=try JSONSerialization.jsonObject(with:data) as? [String:Any]
            else{return}
            climbWorlds=Set((obj["worlds"] as? [Int]) ?? [1])
            climbWorlds.insert(1)
            let blue=(obj["blue_cubes"] as? [[String:Any]]) ?? []
            climbBlueCubes=Set(blue.compactMap { row -> String? in
                guard let world=row["world"] as? Int,let cube=row["cube"] as? Int
                else{return nil}
                return "\(world):\(cube)"
            })
            climbColoredBosses=Set((obj["colored_bosses"] as? [Int]) ?? [])
            climbCharacters=Set((obj["characters"] as? [String]) ?? [])
            if !climbWorlds.contains(climbWorld) &&
                !(climbWorld==11 && climbSecretAvailable) {climbWorld=1}
        } catch {climbMessage="Some world rewards are temporarily unavailable."}
    }
    @MainActor private func enterClimbBlueDoor(_ door:Int) async {
        guard !climbDoorBusy,(1...10).contains(climbWorld),
              climbDoors.contains(door) else{return}
        climbDoorBusy=true
        defer {climbDoorBusy=false}
        let world=climbWorld
        if climbCloudReady && climbSlot==1 {
            do {
                let raw=try await cloud.request("/rest/v1/rpc/itamar_climb_enter_blue_door",
                    method:"POST",data:["p_world":world,"p_cube":door])
                let response=(try JSONSerialization.jsonObject(with:raw)) as? [String:Any] ?? [:]
                climbMessage=(response["blue_collected"] as? Int ?? 0)==5 ?
                    "🔮 World \(world) mystery character unlocked!" :
                    "💙 You discovered a blue cube behind Door \(door)!"
                await loadClimbRewards()
            } catch {climbMessage="Blue door unavailable: \(error.localizedDescription)"}
        } else {
            climbBlueCubes.insert("\(world):\(door)")
            if climbBlueCubes.filter({$0.hasPrefix("\(world):")}).count==5 {
                climbCharacters.insert("mystery_world_\(world)")
                climbMessage="🔮 Mystery character unlocked in the offline preview!"
            } else {climbMessage="💙 Blue cube discovered (local preview)."}
        }
    }
    @MainActor private func unlockClimbWorld(_ world:Int) async {
        guard climbKeyCount>0,(2...10).contains(world) else{return}
        if climbSlot != 1 {
            climbWorlds.insert(world)
            climbMessage="World \(world) unlocked in this save!"
            saveClimb()
            return
        }
        guard climbCloudReady else{return}
        do {
            _=try await cloud.request("/rest/v1/rpc/itamar_climb_unlock_world",
                                      method:"POST",data:["p_world":world])
            await loadClimbRewards()
            climbMessage="World \(world) unlocked!"
        }catch{climbMessage="World unlock unavailable: \(error.localizedDescription)"}
    }
    @MainActor private func claimClimbColoredRewards() async {
        let boss=min(10,max(0,(climbLevel-2)/30))
        guard climbCloudReady,(1...10).contains(boss),
              !climbColoredBosses.contains(boss) else{return}
        if climbSlot != 1 {
            climbColoredBosses.insert(boss)
            saveClimb()
            return
        }
        do {
            let raw=try await cloud.request("/rest/v1/rpc/itamar_climb_claim_colored",
                                    method:"POST",data:["p_boss_index":boss])
            let obj=(try JSONSerialization.jsonObject(with:raw)) as? [String:Any] ?? [:]
            if obj["awarded"] as? Bool == true {
                climbMessage="✨ Rare colored cube found after the boss!"
                await loadClimbRewards()
            }
        }catch {}
    }
    @MainActor private func buyClimbCharacter() async {
        guard climbCoins>=500,!climbCharacterBusy else{return}
        climbCharacterBusy=true
        defer {climbCharacterBusy=false}
        if climbCloudReady && climbSlot==1 {
            climbPendingUpload=false
            climbCloudReady=false
            do {
                let raw=try await cloud.request("/rest/v1/rpc/itamar_climb_buy_random_character",
                    method:"POST",data:[:])
                let result=(try JSONSerialization.jsonObject(with:raw)) as? [String:Any] ?? [:]
                if result["purchased"] as? Bool == true {
                    climbCoins=result["coins"] as? Int ?? climbCoins
                    climbRevision=(result["revision"] as? NSNumber)?.int64Value ?? climbRevision
                    let awarded=result["character"] as? String ?? "unknown"
                    climbCharacters.insert(awarded)
                    climbCharacterNotice="🎉 You unlocked \(CloudClimbHeroes.get(awarded).name)!"
                }else {climbCharacterNotice="You already own all regular characters."}
                climbCloudReady=true
                await loadClimbRewards()
                saveClimb()
            }catch {
                climbCharacterNotice="Could not complete purchase. Your account was not charged here."
                await loadCloudClimb()
            }
        } else {
            let available=(1...12).map {String(format:"sky_%02d",$0)}
                .filter{!climbCharacters.contains($0)}
            guard let new=available.randomElement() else {
                climbCharacterNotice="All regular characters owned."
                return
            }
            climbCoins-=500
            climbCharacters.insert(new)
            climbCharacterNotice="🎉 Offline character: \(CloudClimbHeroes.get(new).name)"
            saveClimb()
        }
    }
    // Game-chat commands adjust only normal settings/available unlocks.
    // /undo reverses the latest command preference/world change; it never reverses earned rewards.
    private func runClimbCommand() {
        let typed=climbSlashInput.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !typed.isEmpty else{return}
        let command=(typed.hasPrefix("/") ? typed : "/"+typed).lowercased()
        climbSlashInput=""
        climbChatMessages.append("You: "+typed)
        let before=(world:climbWorld,hero:climbEquippedHero,twilight:climbTwilightSky,
                    auto:climbAutoHideControls,tips:climbShowTips,paused:climbPaused)
        switch command {
        case "/help", "/commands":
            climbSlashReply="/cancel (options) · /stats · /where · /account · /room · /world N · /world back · /hero list · /hero ID · /hero reset · /theme day|twilight|reset · /controls auto|show|reset · /tips on|off|reset · /pause · /resume · /undo · /cancel · /reset-position · /save · /sync"
        case "/stats", "/status":
            climbSlashReply="Level \(climbLevel) · World \(climbWorld) · Coins \(climbCoins) · Hearts \(climbHearts)/3 · Blue \(climbBlueCubes.count)/50 · Colored \(climbColoredBosses.count)/10 · Heroes \(climbCharacters.count)"
        case "/where", "/world current":
            climbSlashReply="World \(climbWorld), stage \(climbLevel). Use /world N to travel to an unlocked world."
        case "/account":
            climbSlashReply=cloud.isSignedIn ? "Linked to your ItamarOS account. "+climbSyncStatus : "Offline demo · Progress stays on this device."
        case "/room":
            climbSlashReply="Room: \(match?.code ?? "offline")"
        case "/pause":
            climbPaused=true;climbSlashReply="Game paused. Type /resume to continue."
        case "/resume", "/unpause":
            climbPaused=false;climbSlashReply="Game resumed."
        case "/reset-position", "/position reset":
            resetMovement();climbSlashReply="Returned to stage start; progress kept. Movement reset cannot be undone."
        case "/theme day", "/theme reset":
            climbTwilightSky=false;saveClimbPreferences();climbSlashReply="Day theme enabled."
        case "/theme twilight":
            climbTwilightSky=true;saveClimbPreferences();climbSlashReply="Twilight theme enabled."
        case "/controls auto", "/controls reset":
            climbAutoHideControls=true;saveClimbPreferences();climbSlashReply="Touch controls will hide when a controller connects."
        case "/controls show":
            climbAutoHideControls=false;saveClimbPreferences();climbSlashReply="Touch controls will remain visible."
        case "/tips on", "/tips reset":
            climbShowTips=true;saveClimbPreferences();climbSlashReply="Tips enabled."
        case "/tips off":
            climbShowTips=false;saveClimbPreferences();climbSlashReply="Tips disabled."
        case "/hero list":
            climbSlashReply="Unlocked: starter"+(climbCharacters.isEmpty ? "" : ", "+climbCharacters.sorted().joined(separator:", "))
        case "/hero reset":
            climbEquippedHero="starter"
            UserDefaults.standard.set("starter",forKey:climbSaveKey+".hero")
            saveClimbPreferences();climbSlashReply="Default hero equipped."
        case "/world back":
            if let previous=climbChatUndo, previous.world != climbWorld,
               climbWorlds.contains(previous.world) || (previous.world==11 && climbSecretAvailable) {
                climbWorld=previous.world;resetMovement();saveClimb();saveClimbPreferences()
                climbChatUndo=nil
                climbSlashReply="Returned to World \(climbWorld)."
            } else {climbSlashReply="No previous world change to reverse. Use /undo immediately after changing worlds."}
        case "/cancel":
            climbCancelPicker=true
            climbSlashReply="Choose what to cancel in the buttons. Saves and rewards are protected."
        case "/undo", "/revert":
            if let previous=climbChatUndo {
                if previous.world != climbWorld {
                    if climbWorlds.contains(previous.world) || (previous.world==11 && climbSecretAvailable) {
                        climbWorld=previous.world;resetMovement();saveClimb()
                    }
                }
                if CloudClimbHeroes.unlocked(previous.hero,owned:climbCharacters) {
                    climbEquippedHero=previous.hero
                    UserDefaults.standard.set(previous.hero,forKey:climbSaveKey+".hero")
                }
                climbTwilightSky=previous.twilight
                climbAutoHideControls=previous.auto
                climbShowTips=previous.tips
                climbPaused=previous.paused
                climbChatUndo=nil
                saveClimbPreferences()
                climbSlashReply="Last game-chat setting change undone."
            } else {climbSlashReply="Nothing to undo. /undo only reverses the last chat setting change."}
        case "/save":
            saveClimb();saveClimbPreferences()
            climbSlashReply=climbCloudReady ? "Account save requested." : "Saved on this device."
        case "/sync":
            if cloud.isSignedIn {
                Task {await loadCloudClimb()}
                climbSlashReply="Reloading your ItamarOS cloud save."
            } else {climbSlashReply="Sign in to sync. Offline progress stays separate."}
        default:
            if command.hasPrefix("/world "),let number=Int(command.dropFirst(7)),
               climbWorlds.contains(number) || (number==11 && climbSecretAvailable) {
                climbWorld=number;resetMovement();saveClimb();saveClimbPreferences()
                climbSlashReply="Entered World \(number)."
            } else if command.hasPrefix("/hero ") {
                let requested=String(command.dropFirst(6))
                if CloudClimbHeroes.unlocked(requested,owned:climbCharacters) {
                    climbEquippedHero=requested
                    UserDefaults.standard.set(requested,forKey:climbSaveKey+".hero")
                    saveClimbPreferences()
                    climbSlashReply="Equipped \(CloudClimbHeroes.get(requested).name)."
                } else {climbSlashReply="Hero locked. Use /hero list."}
            } else {climbSlashReply="Unknown command or locked world. Type /help."}
        }
        if command != "/undo" && command != "/cancel" && command != "/revert" &&
           command != "/world back" {
            if before.world != climbWorld || before.hero != climbEquippedHero ||
               before.twilight != climbTwilightSky || before.auto != climbAutoHideControls ||
               before.tips != climbShowTips || before.paused != climbPaused {
                climbChatUndo=before
            }
        }
        climbChatMessages.append("Game: "+climbSlashReply)
        if climbChatMessages.count>12 {climbChatMessages.removeFirst(climbChatMessages.count-12)}
    }
    @MainActor private func loadClimbPreferences() async {
        guard cloud.isSignedIn,climbCloudReady else{return}
        do {
            let raw=try await cloud.request("/rest/v1/rpc/itamar_climb_get_preferences",
                                            method:"POST",data:[:])
            guard let prefs=try JSONSerialization.jsonObject(with:raw) as? [String:Any],
                  prefs["exists"] as? Bool == true else{return}
            climbTwilightSky=prefs["twilight_sky"] as? Bool ?? false
            climbAutoHideControls=prefs["auto_hide_controls"] as? Bool ?? true
            climbShowTips=prefs["show_tips"] as? Bool ?? true
            let desiredWorld=prefs["selected_world"] as? Int ?? 1
            climbWorld=(climbWorlds.contains(desiredWorld) ||
                        (desiredWorld==11 && climbSecretAvailable)) ? desiredWorld : 1
            let desiredHero=prefs["equipped_hero"] as? String ?? "starter"
            climbEquippedHero=CloudClimbHeroes.unlocked(desiredHero,owned:climbCharacters)
                ? desiredHero : "starter"
            UserDefaults.standard.set(climbEquippedHero,forKey:climbSaveKey+".hero")
            resetMovement()
        }catch {climbSyncStatus="Cloud progress connected · Preferences unavailable"}
    }
    private func saveClimbPreferences() {
        saveClimb()
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
        let menuPressed=pad?.buttonMenu.isPressed ?? false
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
        var payload=climbGameSnapshot
        payload["bossHealth"]=climbBossHealth
        payload["shopDue"]=climbShopDue
        payload["gameOver"]=climbGameOver
        payload["world"]=climbWorld
        UserDefaults.standard.set(payload,forKey:climbSaveKey)
        if climbCloudReady {
            climbPendingUpload=true
            Task {await uploadClimb()}
        }
    }
    private func loadClimb(){
        climbLoaded=false
        climbCloudReady=false
        climbRevision=0
        climbSlotNames=UserDefaults.standard.stringArray(forKey:climbSlotNameKey) ?? ["My Game 1","My Game 2","My Game 3"]
        let saved=UserDefaults.standard.dictionary(forKey:climbSaveKey) ?? [:]
        climbEquippedHero=UserDefaults.standard.string(forKey:climbSaveKey+".hero") ?? "starter"
        climbLevel=max(1,saved["level"] as? Int ?? 1)
        climbCoins=max(0,saved["coins"] as? Int ?? 0)
        climbHearts=min(3,max(0,saved["hearts"] as? Int ?? 3))
        climbBossHealth=min(3,max(1,saved["bossHealth"] as? Int ?? 3))
        climbShopDue=max(0,saved["shopDue"] as? Int ?? 0)
        climbGameOver=(saved["gameOver"] as? Bool ?? false) || climbHearts==0
        climbWorld=min(11,max(1,saved["world"] as? Int ?? 1))
        climbWorlds=Set((saved["worlds"] as? [Int]) ?? [1])
        climbWorlds.insert(1)
        climbBlueCubes=Set(saved["blue_cubes"] as? [String] ?? [])
        climbColoredBosses=Set(saved["colored_bosses"] as? [Int] ?? [])
        climbCharacters=Set(saved["characters"] as? [String] ?? [])
        climbTwilightSky=saved["twilight_sky"] as? Bool ?? false
        climbAutoHideControls=saved["auto_hide_controls"] as? Bool ?? true
        climbShowTips=saved["show_tips"] as? Bool ?? true
        climbPaused=false;climbMessage="";climbLoaded=true
        resetMovement()
    }
    @MainActor private func loadCloudClimb() async {
        guard cloud.isSignedIn else {
            climbSyncStatus="Local save · Sign in with ItamarOS to sync"
            return
        }
        let requested=climbSlot
        climbCloudReady=false
        do {
            let raw=try await cloud.request("/rest/v1/rpc/itamar_climb_slot_state",
                                            method:"POST",data:["p_slot":requested])
            guard requested==climbSlot,
                  let state=try JSONSerialization.jsonObject(with:raw) as? [String:Any] else{return}
            climbRevision=(state["revision"] as? NSNumber)?.int64Value ?? 0
            if let name=state["name"] as? String,!name.isEmpty{
                climbSlotNames[requested-1]=name
                storeClimbNames()
            }
            if let game=state["game"] as? [String:Any],state["exists"] as? Bool == true {
                climbLevel=max(1,game["level"] as? Int ?? 1)
                climbCoins=max(0,game["coins"] as? Int ?? 0)
                climbHearts=min(3,max(0,game["hearts"] as? Int ?? 3))
                climbBossHealth=min(3,max(1,game["boss_health"] as? Int ?? 3))
                climbShopDue=max(0,game["shop_due"] as? Int ?? 0)
                climbGameOver=(game["game_over"] as? Bool ?? false) || climbHearts==0
                climbWorlds=Set(game["worlds"] as? [Int] ?? [1])
                climbWorlds.insert(1)
                climbBlueCubes=Set(game["blue_cubes"] as? [String] ?? [])
                climbColoredBosses=Set(game["colored_bosses"] as? [Int] ?? [])
                climbCharacters=Set(game["characters"] as? [String] ?? [])
                let requestedWorld=game["selected_world"] as? Int ?? 1
                climbWorld=climbWorlds.contains(requestedWorld) ||
                    (requestedWorld==11 && climbSecretAvailable) ? requestedWorld : 1
                let desiredHero=game["equipped_hero"] as? String ?? "starter"
                climbEquippedHero=CloudClimbHeroes.unlocked(desiredHero,owned:climbCharacters) ?
                    desiredHero : "starter"
                climbTwilightSky=game["twilight_sky"] as? Bool ?? false
                climbAutoHideControls=game["auto_hide_controls"] as? Bool ?? true
                climbShowTips=game["show_tips"] as? Bool ?? true
                UserDefaults.standard.set(climbEquippedHero,forKey:climbSaveKey+".hero")
                resetMovement()
            }
            climbSyncStatus="Game \(requested) connected to your ItamarOS account"
            climbCloudReady=true
            if state["exists"] as? Bool != true {
                saveClimb()
            } else {
                UserDefaults.standard.set(climbGameSnapshot,forKey:climbSaveKey)
            }
        }catch {
            if requested==climbSlot {climbSyncStatus="Local save · Cloud sync unavailable"}
        }
    }
    @MainActor private func uploadClimb() async {
        guard !climbCloudSaving && climbCloudReady else{return}
        climbCloudSaving=true
        defer{climbCloudSaving=false}
        while climbCloudReady && climbPendingUpload {
            climbPendingUpload=false
            let current=climbSlot
            let game=climbGameSnapshot
            let name=climbSlotNames[current-1]
            let rev=climbRevision
            do {
                let raw=try await cloud.request("/rest/v1/rpc/itamar_climb_slot_save",
                    method:"POST",data:["p_slot":current,"p_name":name,"p_game":game,
                                        "p_revision":rev])
                guard current==climbSlot else{return}
                let response=try JSONSerialization.jsonObject(with:raw) as? [String:Any] ?? [:]
                if response["saved"] as? Bool == true {
                    climbRevision=(response["revision"] as? NSNumber)?.int64Value ?? climbRevision
                    climbSyncStatus="Saved \(name) to your ItamarOS account"
                    await claimClimbColoredRewards()
                }else {
                    climbCloudReady=false
                    climbSyncStatus="Newer progress exists on another device · Reloading"
                    await loadCloudClimb()
                }
            }catch {
                climbSyncStatus="Local save · Cloud upload will retry"
                break
            }
        }
    }
    private func finishClimbLevel(){
        let completed=climbLevel
        climbCoins+=10;climbLevel+=1;climbBossHealth=3
        climbShopDue=climbHearts<3 && (climbLevel % 30 == 0 ||
            (completed % 10 == 0 && completed % 30 != 0)) ? climbLevel : 0
        climbMessage="Level \(completed) complete! +10 coins." +
            (completed % 100 == 0 ? " New world key available!" : "")
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
