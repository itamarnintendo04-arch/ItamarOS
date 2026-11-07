import Foundation
import AVFoundation

/// Locally synthesized, original game UI effects; no third-party samples.
@MainActor
final class GameSoundEffects {
    static let shared = GameSoundEffects()
    enum Effect { case jump, coin, victory, tap, damage }
    private var active: [AVAudioPlayer] = []
    private init() {}

    func play(_ effect: Effect, volume: Float = 0.5) {
        let notes: [Double]
        let duration: Double
        switch effect {
        case .jump: notes = [330, 440, 660]; duration = 0.23
        case .coin: notes = [880, 1175, 1568]; duration = 0.28
        case .victory: notes = [523, 659, 784, 1047]; duration = 0.72
        case .tap: notes = [660]; duration = 0.09
        case .damage: notes = [330, 220, 165]; duration = 0.32
        }
        let rate = 22050
        let count = Int(Double(rate) * duration)
        var samples = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / Double(rate)
            let index = min(notes.count - 1, Int(t / duration * Double(notes.count)))
            let frequency = notes[index]
            let fade = pow(max(0, 1 - t / duration), 1.7)
            let wave = sin(2 * .pi * frequency * t) * fade * 0.32
            samples[i] = Int16(wave * Double(Int16.max))
        }
        var data = Data()
        func u16(_ x: UInt16) { var y=x.littleEndian; withUnsafeBytes(of:&y){data.append(contentsOf:$0)} }
        func u32(_ x: UInt32) { var y=x.littleEndian; withUnsafeBytes(of:&y){data.append(contentsOf:$0)} }
        let bytes = count * 2
        data.append(contentsOf: "RIFF".utf8); u32(UInt32(bytes + 36))
        data.append(contentsOf: "WAVEfmt ".utf8)
        u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        data.append(contentsOf: "data".utf8); u32(UInt32(bytes))
        samples.withUnsafeBytes { data.append(contentsOf:$0) }
        do {
            let player = try AVAudioPlayer(data:data)
            player.volume = max(0,min(1,volume))
            active.removeAll(where: { !$0.isPlaying })
            active.append(player)
            player.play()
        } catch { }
    }
}
