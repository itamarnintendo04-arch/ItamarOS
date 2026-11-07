import Foundation
import AVFoundation

/// Original, synthesized ambient game music. No copyrighted samples or downloads.
@MainActor
final class GameMusic: ObservableObject {
    static let shared = GameMusic()
    @Published private(set) var isPlaying = false
    private var player: AVAudioPlayer?
    private init() {}

    func start(style: Style = .clouds) {
        guard !isPlaying else { return }
        let filename = style == .clouds ? "Floating Isles" : "Floating Horizons"
        if let url = Bundle.main.url(forResource: filename, withExtension: "mp3") {
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                player = try AVAudioPlayer(contentsOf: url)
                player?.numberOfLoops = -1
                player?.volume = 0.45
                isPlaying = player?.play() ?? false
                return
            } catch { /* Fallback to built-in synthesized soundtrack */ }
        }
        let sampleRate = 22050
        let seconds = 16
        let notes: [Double] = style == .clouds
            ? [261.63,329.63,392.0,523.25,440.0,392.0,329.63,293.66]
            : [220.0,261.63,329.63,392.0,293.66,261.63,246.94,196.0]
        var samples = [Int16](repeating: 0, count: sampleRate * seconds)
        for i in samples.indices {
            let time = Double(i) / Double(sampleRate)
            let step = Int(time / 2) % notes.count
            let freq = notes[step]
            let phase = time * freq * 2 * Double.pi
            let envelope = min(1.0, (time.truncatingRemainder(dividingBy: 2)) * 4)
            let tone = (sin(phase) * 0.48 + sin(phase * 0.5) * 0.23 + sin(phase * 2) * 0.08) * envelope
            samples[i] = Int16(max(-1,min(1,tone * 0.24)) * Double(Int16.max))
        }
        let pcm = samples.withUnsafeBytes { Data($0) }
        var wav = Data()
        func append16(_ n: UInt16) { var v=n.littleEndian; withUnsafeBytes(of:&v){wav.append(contentsOf:$0)} }
        func append32(_ n: UInt32) { var v=n.littleEndian; withUnsafeBytes(of:&v){wav.append(contentsOf:$0)} }
        wav.append(contentsOf: Array("RIFF".utf8))
        append32(UInt32(36 + pcm.count))
        wav.append(contentsOf: Array("WAVEfmt ".utf8))
        append32(16); append16(1); append16(1)
        append32(UInt32(sampleRate)); append32(UInt32(sampleRate * 2))
        append16(2); append16(16)
        wav.append(contentsOf: Array("data".utf8)); append32(UInt32(pcm.count))
        wav.append(pcm)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode:.default, options:[.mixWithOthers])
            player = try AVAudioPlayer(data:wav)
            player?.numberOfLoops = -1
            player?.volume = 0.45
            isPlaying = player?.play() ?? false
        } catch { isPlaying = false }
    }
    func stop() { player?.stop(); player=nil; isPlaying=false }
    enum Style { case clouds, adventure }
}
