#if os(iOS)
import Foundation
import SwiftUI
import AVFoundation

// Voice messages are locally recorded AAC .m4a files, then uploaded only when
// the user explicitly taps Send. They use existing private room media storage;
// this is NOT a live voice call or end-to-end encrypted media.
@MainActor
final class ItamarVoiceNoteRecorder: ObservableObject {
    @Published private(set) var recording = false
    private var recorder: AVAudioRecorder?
    private var file: URL?

    func start() async throws {
        guard !recording else { return }
        let permitted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { ok in
                continuation.resume(returning: ok)
            }
        }
        guard permitted else {
            throw NSError(domain:"ItamarVoiceNote",code:1,userInfo:[
                NSLocalizedDescriptionKey:"Microphone access was denied in iOS Settings."])
        }
        let session=AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,mode:.default,options:[.defaultToSpeaker])
        try session.setActive(true)
        let target=FileManager.default.temporaryDirectory
            .appendingPathComponent("ItamarOS-Voice-"+UUID().uuidString+".m4a")
        let settings:[String:Any]=[
            AVFormatIDKey:Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey:24000.0,
            AVNumberOfChannelsKey:1,
            AVEncoderAudioQualityKey:AVAudioQuality.medium.rawValue
        ]
        let newRecorder=try AVAudioRecorder(url:target,settings:settings)
        newRecorder.prepareToRecord()
        guard newRecorder.record(forDuration:90) else {
            throw NSError(domain:"ItamarVoiceNote",code:2,userInfo:[
                NSLocalizedDescriptionKey:"Unable to start the recording."])
        }
        file=target
        recorder=newRecorder
        recording=true
    }

    func finish() -> URL? {
        guard recording else { return nil }
        recorder?.stop()
        recorder=nil
        recording=false
        let completed=file
        file=nil
        try? AVAudioSession.sharedInstance().setActive(false)
        return completed
    }

    func discard() {
        let old=finish()
        if let old { try? FileManager.default.removeItem(at:old) }
    }
}
#endif
