#if os(iOS)
import SwiftUI
import CoreImage.CIFilterBuiltins
import GameController

private struct CloudClimbPairStart: Decodable {
    let requestId:String
    let claimSecret:String
    let approveUrl:String
    let expiresAt:Double
}
private struct CloudClimbPairResult: Decodable {
    let status:String?
    let accessToken:String?
    let userId:String?
    let error:String?
}

/// Independent iOS prototype. Online rooms and game progress use the same
/// authenticated Supabase backend as ItamarOS. Approval is required in the
/// separately installed trusted ItamarOS mobile application.
@main
struct CloudClimbStandaloneApp: App {
    @StateObject private var cloud=ItamarCloudService()
    var body:some Scene {
        WindowGroup {
            CloudClimbStandaloneHome()
                .environmentObject(cloud)
                .environment(\.locale,Locale(identifier:"en"))
        }
    }
}

struct CloudClimbStandaloneHome:View {
    @EnvironmentObject private var cloud:ItamarCloudService
    @Environment(\.openURL) private var openURL
    @State private var qrVisible=false
    @State private var pair:CloudClimbPairStart?
    @State private var info="Link the account already signed in on your ItamarOS phone."
    @State private var working=false
    @State private var showOnline=false
    @State private var activeRequest:UUID?
    @State private var offlineDemo=false
    private let broker="https://itamaros-store-api.onrender.com/api/connect/pair"

    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:16) {
                    Image("BrandMark").resizable().scaledToFit()
                        .frame(width:82,height:82)
                    Text("CLOUD CLIMB")
                        .font(.system(size:32,weight:.black,design:.rounded))
                    Text("Original platform adventure · Standalone Preview")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if cloud.isSignedIn {
                        Text("Your ItamarOS account is connected")
                            .foregroundStyle(.green)
                        if let username=cloud.profile?.username {
                            Text("@"+username)
                        }
                        Button("Play Online · Shared Room Codes") {showOnline=true}
                            .buttonStyle(.borderedProminent)
                        Button("Sign Out") {cloud.signOut()}
                            .buttonStyle(.bordered)
                        Text("Your approved session is temporary. Reconnect if it expires.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Button("Play Offline Demo") {offlineDemo=true}
                            .buttonStyle(.borderedProminent)
                        Button(working ? "Connecting…" : "Continue with ItamarOS · No QR") {
                            Task {await startPair(openInApp:true)}
                        }.buttonStyle(.borderedProminent).disabled(working || pair != nil)
                        Button("Use QR Code Instead") {
                            Task {await startPair(openInApp:false)}
                        }.buttonStyle(.bordered).disabled(working || pair != nil)
                        if let pair {
                            if qrVisible,let image=makeQRCode(pair.approveUrl) {
                                ZStack {
                                    Image(uiImage:image)
                                        .interpolation(.none)
                                        .resizable().scaledToFit()
                                        .frame(width:260,height:260)
                                    Image("BrandMark")
                                        .resizable().scaledToFit()
                                        .padding(7)
                                        .frame(width:52,height:52)
                                        .background(.white,in:RoundedRectangle(cornerRadius:10))
                                }
                                .accessibilityLabel("QR code to approve Cloud Climb login in ItamarOS")
                            }
                            Text("Compare code: "+String(pair.requestId.prefix(6)).uppercased())
                                .font(.headline.monospaced())
                            Text(qrVisible
                                ? "Scan the QR with a trusted ItamarOS phone, then verify and approve."
                                : "Confirm this code in ItamarOS on this phone, then return to Cloud Climb. No QR is needed.")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Cancel") {activeRequest=nil;self.pair=nil;qrVisible=false}
                        }
                    }
                    if !info.isEmpty {
                        Text(info).font(.footnote).multilineTextAlignment(.center)
                    }
                    Text("No SMS or QR is required when both apps are installed on the same device. You must approve this login in your signed-in ItamarOS app.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth:.infinity)
            }
            .background(
                LinearGradient(colors:[Color(red:0.08,green:0.17,blue:0.36),.cyan.opacity(0.27)],
                    startPoint:.top,endPoint:.bottom).ignoresSafeArea()
            )
            .navigationTitle("Cloud Climb")
            .sheet(isPresented:$showOnline) {
                ItamarPartyGamesView(defaultGame:"cloud_climb")
                    .environmentObject(cloud)
            }
            .sheet(isPresented:$offlineDemo) {
                CloudClimbOfflineDemo()
            }
        }
    }

    private func makeQRCode(_ value:String)->UIImage? {
        let generator=CIFilter.qrCodeGenerator()
        generator.message=Data(value.utf8)
        generator.correctionLevel="H"
        guard let image=generator.outputImage else{return nil}
        let scaled=image.transformed(by:CGAffineTransform(scaleX:10,y:10))
        let context=CIContext()
        guard let cg=context.createCGImage(scaled,from:scaled.extent) else{return nil}
        return UIImage(cgImage:cg)
    }

    private func post(_ route:String,_ data:[String:Any]) async throws -> (Int,Data) {
        guard let url=URL(string:broker+route) else{throw URLError(.badURL)}
        var req=URLRequest(url:url)
        req.httpMethod="POST";req.timeoutInterval=13
        req.setValue("application/json",forHTTPHeaderField:"Content-Type")
        req.httpBody=try JSONSerialization.data(withJSONObject:data)
        let (body,response)=try await URLSession.shared.data(for:req)
        guard let http=response as? HTTPURLResponse else{throw URLError(.badServerResponse)}
        return (http.statusCode,body)
    }

    @MainActor private func startPair(openInApp:Bool) async {
        activeRequest=nil;pair=nil;qrVisible = !openInApp;working=true
        defer {working=false}
        do {
            let (code,data)=try await post("/start",[:])
            guard code==200 else{throw URLError(.badServerResponse)}
            let new=try JSONDecoder().decode(CloudClimbPairStart.self,from:data)
            guard URL(string:new.approveUrl)?.host=="itamaros-web-emulator.onrender.com" else{
                throw URLError(.badURL)
            }
            let run=UUID()
            activeRequest=run;pair=new
            info = openInApp
                ? "Approve this request in ItamarOS on your phone, then return to Cloud Climb."
                : "Open ItamarOS on a signed-in phone and approve this request."
            Task {await pollPair(new,run:run)}
            if openInApp,let destination=URL(string:"itamaros://cloud-climb?request="+new.requestId) {
                // The URL contains an untrusted request ID only — no account
                // password, claim secret or access token is shared via deep link.
                openURL(destination) { accepted in
                    if !accepted {
                        info="ItamarOS could not be opened. Install it or cancel and use QR linking."
                    }
                }
            }
        }catch {
            info="Account linking unavailable: "+error.localizedDescription
        }
    }
    @MainActor private func pollPair(_ entry:CloudClimbPairStart,run:UUID) async {
        while activeRequest==run && Date().timeIntervalSince1970*1000<entry.expiresAt {
            try? await Task.sleep(for:.seconds(2.3))
            if activeRequest != run {return}
            do{
                let (code,data)=try await post("/claim",[
                    "requestId":entry.requestId,"claimSecret":entry.claimSecret
                ])
                if code==202 {continue}
                let result=try JSONDecoder().decode(CloudClimbPairResult.self,from:data)
                if code==200, result.status=="approved",
                   let token=result.accessToken,let rawUser=result.userId,
                   let userID=UUID(uuidString:rawUser) {
                    try await cloud.acceptTemporaryQRSession(access:token,userID:userID)
                    activeRequest=nil;pair=nil
                    info="Account approved. Online room codes are shared with ItamarOS."
                    return
                }
                activeRequest=nil;pair=nil
                info=result.error ?? "QR expired. Generate a new code."
            }catch {
                info="Waiting for approval · Check your connection."
            }
        }
        if activeRequest==run {activeRequest=nil;pair=nil;info="QR expired. Try again."}
    }
}

/// Offline playable preview. Save data stays on this device only.
/// Signed-in online play uses the same shared Cloud Climb game as ItamarOS.
private struct CloudClimbOfflineDemo:View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cloudclimb.offline.level") private var level=1
    @AppStorage("cloudclimb.offline.coins") private var coins=0
    @AppStorage("cloudclimb.offline.hearts") private var hearts=3
    @AppStorage("cloudclimb.offline.bossHP") private var bossHP=3
    @AppStorage("cloudclimb.offline.shop") private var shopDue=0
    @AppStorage("cloudclimb.offline.world") private var world=1
    @AppStorage("cloudclimb.offline.blue") private var blueStorage=""
    @AppStorage("cloudclimb.offline.colored") private var coloredStorage=""
    @AppStorage("cloudclimb.offline.characters") private var characterStorage=""
    @AppStorage("cloudclimb.offline.equippedHero") private var equippedHero="starter"
    @AppStorage("cloudclimb.offline.worlds") private var worldStorage=""
    @State private var x:CGFloat=48
    @State private var y:CGFloat=430
    @State private var velocity:CGFloat=0
    @State private var grounded=true
    @State private var left=false
    @State private var right=false
    @State private var jump=false
    @State private var paused=false
    @State private var finished=false
    @State private var notice="Complete stages to earn game coins and discover blue doors."
    @State private var orbOpen=false
    @State private var lastBossHit=Date.distantPast
    @State private var controllerConnected=false
    @State private var lastMenuButton=false
    private let clock=Timer.publish(every:1.0/30.0,on:.main,in:.common).autoconnect()

    private var blue:Set<String> {Set(blueStorage.split(separator:",").map(String.init))}
    private var colored:Set<Int> {Set(coloredStorage.split(separator:",").compactMap{Int($0)})}
    private var characters:Set<String> {Set(characterStorage.split(separator:",").map(String.init))}
    private var worlds:Set<Int> {Set([1]).union(worldStorage.split(separator:",").compactMap{Int($0)})}
    private var keys:Int {max(0,(level-1)/100-(worlds.count-1))}
    private var boss:Bool {level%30==0}
    private var secret:Bool {colored.count==10}
    private var stages:[CGRect] {
        var value=UInt64(UInt32(truncatingIfNeeded:level &* 2039 &+ world &* 1009))
        func rnd()->CGFloat {
            value=value &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((value>>32)%1000)/1000
        }
        var output=[CGRect(x:0,y:472,width:400,height:20)]
        for row in 0..<6 {
            output.append(CGRect(x:16+rnd()*205,y:405-CGFloat(row)*61,
                                 width:130+rnd()*40,height:12))
        }
        return output
    }
    private var remainingDoors:[Int] {
        guard (1...10).contains(world) else{return []}
        return (1...5).filter{!blue.contains("\(world):\($0)")}
    }
    private var nearbyDoor:Int? {
        remainingDoors.first { index in
            abs(x-stages[index].midX)<60 && abs(y-(stages[index].minY-5))<60
        }
    }
    private var bossX:CGFloat {stages.last?.midX ?? 200}

    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:14) {
                    Text("☁️ CLOUD CLIMB")
                        .font(.system(.title,design:.rounded).bold())
                        .foregroundStyle(.white)
                    HStack {
                        Text("LEVEL \(level)").font(.headline).foregroundStyle(.yellow)
                        Spacer()
                        Text("❤️ \(hearts)/3   🪙 \(coins)")
                            .foregroundStyle(.white)
                    }
                    Text("World \(world) · 🔑 \(keys) · 💙 \(blue.count)/50 · 🌈 \(colored.count)/10")
                        .font(.caption.bold()).foregroundStyle(.white)
                    ScrollView(.horizontal,showsIndicators:false) {
                        HStack(spacing:8) {
                            ForEach(1...11,id:\.self) { selected in
                                let open=worlds.contains(selected)||(selected==11 && secret)
                                Button(selected==11 ? "SECRET" :
                                       open ? "World \(selected)" : "🔒 \(selected)") {
                                    if open {
                                        world=selected;resetPosition()
                                    } else if selected<=10 && keys>0 {
                                        worldStorage=Array(worlds.union([selected]))
                                            .sorted().map(String.init).joined(separator:",")
                                        notice="World \(selected) unlocked with a key!"
                                    }
                                }.disabled(!open && keys<1)
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                    if boss {
                        Text("BOSS ENCOUNTER · \(bossHP)/3")
                            .font(.headline).foregroundStyle(.yellow)
                    }
                    HStack {
                        Button(paused ? "Resume" : "Pause") {paused.toggle()}
                            .disabled(shopDue>0 || finished)
                        Button("Exit to Menu") {dismiss()}
                    }.buttonStyle(.bordered)
                    if finished {
                        Text("No hearts left · Try Again").foregroundStyle(.white)
                        Button("Try Again") {
                            hearts=3;bossHP=3;finished=false;resetPosition()
                        }.buttonStyle(.borderedProminent)
                    } else if shopDue>0 {
                        Text(shopDue%30==0 ?
                             "Before Boss Level \(shopDue): buy one missing heart?" :
                             "Heart Shop: restore one missing heart?")
                            .foregroundStyle(.white)
                        HStack {
                            Button("Buy Heart · 100 🪙") {
                                guard hearts<3 && coins>=100 else{return}
                                coins-=100;hearts+=1;shopDue=0
                            }.disabled(hearts==3||coins<100)
                            Button("Skip") {shopDue=0}
                        }.buttonStyle(.borderedProminent)
                    } else if paused {
                        Text("Paused · Progress saves automatically.")
                            .foregroundStyle(.white)
                        Button("Resume") {paused=false}
                    } else {
                        Canvas {ctx,size in
                            let sx=size.width/400,sy=size.height/500
                            ctx.fill(Path(CGRect(origin:.zero,size:size)),
                                with:.linearGradient(Gradient(colors:[.indigo,.cyan.opacity(0.9)]),
                                    startPoint:.zero,
                                    endPoint:CGPoint(x:size.width,y:size.height)))
                            for (index,p) in stages.enumerated() {
                                ctx.fill(Path(roundedRect:CGRect(x:p.minX*sx,y:p.minY*sy,
                                    width:p.width*sx,height:p.height*sy),cornerRadius:6),
                                    with:.color(index==0 ? .mint:.white))
                            }
                            for door in remainingDoors {
                                let p=stages[door]
                                let rect=CGRect(x:(p.midX-12)*sx,y:(p.minY-37)*sy,
                                                width:24*sx,height:37*sy)
                                ctx.fill(Path(roundedRect:rect,cornerRadius:7),with:.color(.blue))
                                ctx.draw(Text("✦").font(.system(size:13)).foregroundColor(.white),
                                         at:CGPoint(x:p.midX*sx,y:(p.minY-18)*sy))
                            }
                            if boss {
                                let rect=CGRect(x:(bossX-21)*sx,y:45*sy,width:42*sx,height:42*sy)
                                ctx.fill(Path(ellipseIn:rect),with:.color(.purple))
                            }
                            CloudClimbHeroes.draw(ctx,
                                hero:CloudClimbHeroes.unlocked(equippedHero,owned:characters)
                                    ? equippedHero : "starter",
                                x:x,y:y,sx:sx,sy:sy)
                            ctx.draw(Text(CloudClimbHeroes.get(equippedHero).name)
                                .font(.system(size:11,weight:.bold)),
                                at:CGPoint(x:x*sx,y:(y-36)*sy))
                        }
                        .aspectRatio(4/5,contentMode:.fit)
                        .clipShape(RoundedRectangle(cornerRadius:16))
                        .onReceive(clock) {_ in tick()}
                        if let door=nearbyDoor {
                            Button("🚪 Enter Blue Door \(door)") {enterDoor(door)}
                                .buttonStyle(.borderedProminent)
                        }
                        if boss {
                            Button("Strike Boss · \(bossHP) Hits Left") {hitBoss()}
                                .disabled(!grounded||y>=115||abs(x-bossX)>=85)
                                .buttonStyle(.borderedProminent)
                        }
                        if !controllerConnected {
                            HStack(spacing:15) {
                                control("◀",left:true)
                                control("▶",left:false)
                                Button("Jump") {jump=true}
                                    .buttonStyle(.borderedProminent)
                            }
                        } else {
                            Text("🎮 Controller connected · A: Jump · X: Strike · Menu: Pause")
                                .font(.caption).foregroundStyle(.white)
                        }
                    }
                    Text(notice).font(.caption).foregroundStyle(.white)
                    CloudClimbHeroPicker(owned:characters,selected:$equippedHero)
                    Button("🔮 Character Orb · \(characters.count) Characters") {
                        orbOpen=true
                    }
                    .frame(maxWidth:.infinity)
                    .buttonStyle(.borderedProminent)
                    Text("Offline preview · Game coins have no real-money value. Signed-in online progress uses the shared ItamarOS database.")
                        .font(.caption2).foregroundStyle(.white.opacity(0.85))
                    Button("Back to Menu") {dismiss()}
                        .buttonStyle(.bordered)
                }.padding(18)
            }
            .background(LinearGradient(colors:[Color(red:0.1,green:0.2,blue:0.48),.teal],
                startPoint:.topLeading,endPoint:.bottomTrailing).ignoresSafeArea())
            .navigationTitle("Cloud Climb")
            .sheet(isPresented:$orbOpen) {
                NavigationStack {
                    VStack(spacing:16) {
                        Text("🔮").font(.system(size:70))
                        Text("Surprise Character").font(.title2.bold())
                        Text("Unlock one random new character for 500 earned game coins.")
                        Text("Owned: \(characters.count) · 🪙 \(coins)")
                        Button("Unlock · 500 Coins") {buyRandomCharacter()}
                            .disabled(coins<500 || characters.filter{$0.hasPrefix("sky_")}.count>=12)
                            .buttonStyle(.borderedProminent)
                        Text(notice).font(.caption)
                        Spacer()
                    }
                    .padding()
                    .navigationTitle("Character Orb")
                    .toolbar {ToolbarItem(placement:.confirmationAction) {
                        Button("Done"){orbOpen=false}
                    }}
                }
            }
        }
    }
    private func control(_ name:String,left:Bool)->some View {
        Text(name).font(.title2.bold()).padding(15)
            .background(.thinMaterial,in:RoundedRectangle(cornerRadius:12))
            .gesture(DragGesture(minimumDistance:0).onChanged{_ in
                if left {self.left=true}else{right=true}
            }.onEnded{_ in
                if left {self.left=false}else{right=false}
            })
    }
    private func tick() {
        let pad=GCController.controllers().first?.extendedGamepad
        controllerConnected=pad != nil
        let menuPressed=pad?.buttonMenu.isPressed ?? false
        if menuPressed && !lastMenuButton && shopDue==0 && !finished {
            paused.toggle()
        }
        lastMenuButton=menuPressed
        guard !paused,!finished,shopDue==0 else{return}
        if pad?.buttonX.isPressed ?? false {hitBoss()}
        let axis=CGFloat(pad?.leftThumbstick.xAxis.value ?? 0)
        let input=(left ? -1.0:0.0)+(right ? 1.0:0.0)+Double(axis)
        x=min(388,max(12,x+CGFloat(max(-1,min(1,input)))*3.2))
        if (jump || pad?.buttonA.isPressed == true) && grounded {
            velocity = -9;grounded=false
        }
        jump=false
        let previousBottom=y+3
        velocity=min(10,velocity+0.38)
        y+=velocity
        if velocity>=0 {
            grounded=false
            for platform in stages {
                if x+11>platform.minX && x-11<platform.maxX &&
                    previousBottom<=platform.minY && y+3>=platform.minY {
                    y=platform.minY-3;velocity=0;grounded=true;break
                }
            }
        }
        if y>495 {
            hearts=max(0,hearts-1)
            if hearts==0 {finished=true;notice="No hearts remaining."}
            resetPosition()
            return
        }
        if grounded && y<110 && !boss {completeLevel()}
    }
    private func resetPosition() {
        x=48;y=430;velocity=0;grounded=true;left=false;right=false;jump=false
    }
    private func hitBoss() {
        guard boss,!paused,!finished,shopDue==0,
              grounded,y<115,abs(x-bossX)<85,
              Date().timeIntervalSince(lastBossHit)>=0.9 else{return}
        lastBossHit=Date()
        if bossHP==1 {completeLevel()}
        else {bossHP-=1;notice="Boss hit! \(bossHP) hits remaining."}
    }
    private func completeLevel() {
        let cleared=level
        coins+=10;level+=1;bossHP=3
        shopDue=hearts<3 && (level%30==0 ||
            (cleared%10==0 && cleared%30 != 0)) ? level : 0
        var rewardMessage="Level \(cleared) complete! +10 coins."
        for index in 1...10 {
            let due=index*30+1+((index*7+5)%3)
            if cleared==due && !colored.contains(index) {
                var updated=colored;updated.insert(index)
                coloredStorage=updated.sorted().map(String.init).joined(separator:",")
                rewardMessage+=" 🌈 Found a colored cube after the boss!"
            }
        }
        notice=rewardMessage
        if cleared%100==0 {notice+=" 🔑 Earned a new world key!"}
        resetPosition()
    }
    private func enterDoor(_ door:Int) {
        guard remainingDoors.contains(door),nearbyDoor==door else{return}
        var updated=blue;updated.insert("\(world):\(door)")
        blueStorage=updated.sorted().joined(separator:",")
        if updated.filter({$0.hasPrefix("\(world):")}).count==5 {
            var unlocked=characters;unlocked.insert("mystery_world_\(world)")
            characterStorage=unlocked.sorted().joined(separator:",")
            notice="🔮 Mystery character from World \(world) unlocked!"
        } else {notice="💙 Found blue cube \(door) in World \(world)!"}
    }
    private func buyRandomCharacter() {
        guard coins>=500 else{return}
        let options=(1...12).map{String(format:"sky_%02d",$0)}
                        .filter{!characters.contains($0)}
        guard let next=options.randomElement() else {
            notice="All regular characters already unlocked."
            return
        }
        coins-=500
        var unlocked=characters;unlocked.insert(next)
        characterStorage=unlocked.sorted().joined(separator:",")
        notice="🎉 New character: \(CloudClimbHeroes.get(next).name)!"
    }
}
#endif