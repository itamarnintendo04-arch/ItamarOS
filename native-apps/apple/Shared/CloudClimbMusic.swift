#if os(iOS)
import Foundation
import AVFoundation

/// Original, generated instrumental loop; no third-party music assets.
@MainActor
final class CloudClimbMusic {
    static let shared = CloudClimbMusic()
    private var player: AVAudioPlayer?
    private init() {}

    func start(enabled: Bool) {
        guard enabled else { stop(); return }
        if let player { if !player.isPlaying { player.play() }; return }
        let sampleRate = 22050
        let bpm = 112.0
        let beat = 60.0 / bpm
        let melody: [Double] = [523.25,659.25,783.99,659.25,587.33,698.46,880,698.46,
                                523.25,659.25,783.99,1046.5,880,783.99,659.25,587.33]
        let bass: [Double] = [130.81,174.61,196.0,146.83]
        let duration = beat * Double(melody.count)
        let frames = Int(duration * Double(sampleRate))
        var pcm = Data(capacity: frames * 2)
        for index in 0..<frames {
            let time = Double(index) / Double(sampleRate)
            let step = min(melody.count - 1, Int(time / beat))
            let local = time.truncatingRemainder(dividingBy: beat)
            let envelope = min(1, local * 35) * min(1, (beat-local) * 8)
            let lead = sin(2 * .pi * melody[step] * time) * envelope * 0.15
            let chord = sin(2 * .pi * bass[(step / 4) % bass.count] * time) * 0.075
            let sparkle = sin(2 * .pi * melody[step] * 2 * time) * envelope * 0.022
            let value = Int16(max(-32767,min(32767,Int((lead + chord + sparkle) * 32767))))
            let bits = UInt16(bitPattern: value)
            pcm.append(UInt8(truncatingIfNeeded: bits))
            pcm.append(UInt8(truncatingIfNeeded: bits >> 8))
        }
        func little(_ number: UInt32) -> [UInt8] {
            [UInt8(truncatingIfNeeded:number),UInt8(truncatingIfNeeded:number >> 8),
             UInt8(truncatingIfNeeded:number >> 16),UInt8(truncatingIfNeeded:number >> 24)]
        }
        var wav = Data("RIFF".utf8)
        wav.append(contentsOf: little(UInt32(36 + pcm.count)))
        wav.append(contentsOf: Array("WAVEfmt ".utf8))
        wav.append(contentsOf: little(16))
        wav.append(contentsOf: [1,0,1,0])
        wav.append(contentsOf: little(UInt32(sampleRate)))
        wav.append(contentsOf: little(UInt32(sampleRate * 2)))
        wav.append(contentsOf: [2,0,16,0])
        wav.append(contentsOf: Array("data".utf8))
        wav.append(contentsOf: little(UInt32(pcm.count)))
        wav.append(pcm)
        do {
            let audio = try AVAudioPlayer(data:wav)
            audio.numberOfLoops = -1
            audio.volume = 0.32
            audio.prepareToPlay()
            audio.play()
            player = audio
        } catch {
            print("Cloud Climb music unavailable: \\(error.localizedDescription)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
#endif
