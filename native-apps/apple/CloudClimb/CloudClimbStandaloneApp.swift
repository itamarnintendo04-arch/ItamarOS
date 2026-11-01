#if os(iOS)
import SwiftUI
import CoreImage.CIFilterBuiltins

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
                        Text("This QR session is temporary. If it expires, reapprove on a trusted device.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Button("Play Offline Demo") {offlineDemo=true}
                            .buttonStyle(.borderedProminent)
                        Button(working ? "Creating QR…" : "Link ItamarOS Account") {
                            Task {await startPair()}
                        }.disabled(working)
                        if let pair {
                            if let image=makeQRCode(pair.approveUrl) {
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
                            Text("Scan the QR on a trusted phone with ItamarOS installed. Approve only after Face ID and verifying the code.")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Cancel") {activeRequest=nil;self.pair=nil}
                        }
                    }
                    if !info.isEmpty {
                        Text(info).font(.footnote).multilineTextAlignment(.center)
                    }
                    Text("No SMS is sent by Cloud Climb. A previously authenticated ItamarOS device is needed for QR linking.")
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

    @MainActor private func startPair() async {
        activeRequest=nil;pair=nil;working=true
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
            info="Open ItamarOS on a signed-in phone and approve this request."
            Task {await pollPair(new,run:run)}
        }catch {
            info="QR unavailable: "+error.localizedDescription
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

/// Small standalone local demonstration. The shared multiplayer version lives
/// inside ItamarPartyGamesView and is available after QR account linking.
private struct CloudClimbOfflineDemo:View {
    @Environment(\.dismiss) private var dismiss
    @State private var x:CGFloat=50
    @State private var score=0
    var body:some View {
        VStack(spacing:20) {
            Text("CLOUD CLIMB · OFFLINE DEMO").font(.title2.bold())
            Text("Moves: \(score)")
            Canvas {ctx,size in
                ctx.fill(Path(CGRect(origin:.zero,size:size)),
                    with:.linearGradient(Gradient(colors:[.indigo,.cyan]),
                        startPoint:.zero,endPoint:CGPoint(x:size.width,y:size.height)))
                for row in 0..<6 {
                    let y=size.height-CGFloat(row+1)*56
                    ctx.fill(Path(roundedRect:CGRect(x:20+CGFloat(row%2)*38,y:y,width:150,height:13),
                        cornerRadius:6),with:.color(.white))
                }
                ctx.fill(Path(ellipseIn:CGRect(x:x,y:size.height-74,width:24,height:24)),
                    with:.color(.orange))
            }
            .frame(height:390).clipShape(RoundedRectangle(cornerRadius:18))
            HStack(spacing:22) {
                Button("◀") {x=max(0,x-20);score+=1}
                Button("Jump") {score+=1}
                Button("▶") {x=min(245,x+20);score+=1}
            }.buttonStyle(.borderedProminent)
            Text("This is a basic offline visual demo. Real rooms and saved worlds require the linked account.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Back to Menu") {dismiss()}
        }.padding()
    }
}
#endif