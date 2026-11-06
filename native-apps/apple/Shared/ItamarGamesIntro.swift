#if os(iOS)
import SwiftUI
import AVFoundation

@MainActor
final class ItamarGamesIntroAudio {
    static let shared = ItamarGamesIntroAudio()
    private var player: AVAudioPlayer?
    func play(volume: Double) {
        let rate = 22050
        let notes: [Double] = [392, 523.25, 659.25, 783.99, 1046.5]
        let duration = 2.4
        var samples = Data()
        for i in 0..<Int(Double(rate) * duration) {
            let t = Double(i) / Double(rate)
            var sound = 0.0
            for (n, frequency) in notes.enumerated() {
                let start = Double(n) * 0.36
                let elapsed = t - start
                if elapsed >= 0 && elapsed < 0.9 {
                    let envelope = min(1, elapsed * 25) * exp(-elapsed * 4)
                    sound += sin(2 * .pi * frequency * elapsed) * envelope * 0.26
                    sound += sin(2 * .pi * frequency * 2 * elapsed) * envelope * 0.04
                }
            }
            let v = UInt16(bitPattern: Int16(max(-32767, min(32767, Int(sound * 32767)))))
            samples.append(UInt8(truncatingIfNeeded:v))
            samples.append(UInt8(truncatingIfNeeded:v >> 8))
        }
        func le(_ v: UInt32) -> [UInt8] {
            [UInt8(truncatingIfNeeded:v),UInt8(truncatingIfNeeded:v >> 8),
             UInt8(truncatingIfNeeded:v >> 16),UInt8(truncatingIfNeeded:v >> 24)]
        }
        var data = Data("RIFF".utf8)
        data.append(contentsOf:le(UInt32(36 + samples.count)))
        data.append(contentsOf:Array("WAVEfmt ".utf8))
        data.append(contentsOf:le(16))
        data.append(contentsOf:[1,0,1,0])
        data.append(contentsOf:le(UInt32(rate)))
        data.append(contentsOf:le(UInt32(rate*2)))
        data.append(contentsOf:[2,0,16,0])
        data.append(contentsOf:Array("data".utf8))
        data.append(contentsOf:le(UInt32(samples.count)))
        data.append(samples)
        if let audio = try? AVAudioPlayer(data:data) {
            audio.volume = Float(max(0,min(1,volume)))
            audio.play()
            player = audio
        }
    }
    func stop() { player?.stop(); player=nil }
}

struct ItamarGamesLaunchView<Content: View>: View {
    @AppStorage("itamaros.settings.music") private var music = true
    @AppStorage("itamaros.settings.musicVolume") private var musicVolume = 1.0
    @State private var showing = true
    let content: Content
    var body: some View {
        ZStack {
            content.opacity(showing ? 0 : 1).allowsHitTesting(!showing)
            if showing {
                ItamarGamesLogoAssembly()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            if music { ItamarGamesIntroAudio.shared.play(volume:musicVolume) }
            try? await Task.sleep(for:.seconds(2.65))
            withAnimation(.easeOut(duration:0.4)) { showing=false }
        }
        .onDisappear { ItamarGamesIntroAudio.shared.stop() }
    }
}

private struct ItamarGamesLogoAssembly: View {
    @State private var assembled = false
    var body: some View {
        ZStack {
            LinearGradient(colors:[.indigo,.blue,.cyan],startPoint:.top,endPoint:.bottom)
                .ignoresSafeArea()
            VStack(spacing:18) {
                ZStack {
                    Image(systemName:"cloud.fill")
                        .font(.system(size:110)).foregroundStyle(.white)
                        .offset(x:assembled ? 0 : -500)
                    Image(systemName:"gamecontroller.fill")
                        .font(.system(size:65)).foregroundStyle(.indigo)
                        .offset(x:assembled ? 0 : 500)
                    Image(systemName:"sparkles")
                        .font(.system(size:120)).foregroundStyle(.yellow)
                        .scaleEffect(assembled ? 1 : 0)
                }
                Text("ItamarOS")
                    .font(.system(size:48,weight:.black,design:.rounded))
                    .italic().tracking(-2)
                    .foregroundStyle(.white)
                    .shadow(color:.indigo,radius:5,x:3,y:4)
                    .offset(y:assembled ? 0 : 180)
                Text("GAMES")
                    .font(.system(size:38,weight:.black,design:.rounded))
                    .italic().tracking(5)
                    .foregroundStyle(.yellow)
                    .offset(y:assembled ? 0 : 180)
            }
            .animation(.spring(response:1.1,dampingFraction:0.72),value:assembled)
        }
        .onAppear { assembled=true }
    }
}
#endif
