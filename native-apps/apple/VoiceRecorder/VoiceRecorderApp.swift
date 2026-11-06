import SwiftUI
import AVFoundation

@main
struct ItamarVoiceRecorderApp: App {
    var body: some Scene {
        WindowGroup { VoiceRecorderHome() }
    }
}

@MainActor
final class VoiceRecorderStore: ObservableObject {
    @Published var recording=false
    @Published var recordings:[URL]=[]
    @Published var message=""
    private var recorder:AVAudioRecorder?
    private var player:AVAudioPlayer?
    private var folder:URL {
        let dir=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Recordings",isDirectory:true)
        try? FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        return dir
    }
    init(){refresh()}
    func refresh() {
        recordings=((try? FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil)) ?? [])
            .filter{$0.pathExtension=="m4a"}
            .sorted{$0.lastPathComponent > $1.lastPathComponent}
    }
    func start() async {
        let allowed=await withCheckedContinuation { (continuation:CheckedContinuation<Bool,Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission {continuation.resume(returning:$0)}
        }
        guard allowed else {message="Enable microphone access in Settings.";return}
        do {
            let session=AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord,mode:.default,options:[.defaultToSpeaker])
            try session.setActive(true)
            let url=folder.appendingPathComponent("Recording-\(Int(Date().timeIntervalSince1970)).m4a")
            let settings:[String:Any]=[
                AVFormatIDKey:Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey:44100,
                AVNumberOfChannelsKey:1,
                AVEncoderAudioQualityKey:AVAudioQuality.high.rawValue
            ]
            recorder=try AVAudioRecorder(url:url,settings:settings)
            recording=recorder?.record() ?? false
            if !recording {message="Unable to start recording."}
        } catch {message=error.localizedDescription}
    }
    func stop(){
        recorder?.stop()
        recorder=nil
        recording=false
        try? AVAudioSession.sharedInstance().setActive(false)
        refresh()
    }
    func play(_ url:URL) {
        do {
            player=try AVAudioPlayer(contentsOf:url)
            player?.play()
        } catch {message=error.localizedDescription}
    }
    func delete(_ url:URL){
        try? FileManager.default.removeItem(at:url)
        refresh()
    }
}

struct VoiceRecorderHome: View {
    @StateObject private var store=VoiceRecorderStore()
    var body:some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        if store.recording {store.stop()}
                        else {Task {await store.start()}}
                    } label: {
                        Label(store.recording ? "Stop recording" : "Start recording",systemImage:store.recording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title2.bold())
                            .frame(maxWidth:.infinity,minHeight:76)
                    }
                    .tint(store.recording ? .red : .purple)
                    if !store.message.isEmpty {Text(store.message).foregroundStyle(.secondary)}
                }
                Section("Saved recordings") {
                    if store.recordings.isEmpty {Text("No recordings yet.").foregroundStyle(.secondary)}
                    ForEach(store.recordings,id:\.self) {url in
                        HStack {
                            Button {store.play(url)} label: {Label(url.deletingPathExtension().lastPathComponent,systemImage:"play.circle")}
                            Spacer()
                            ShareLink(item:url) {Image(systemName:"square.and.arrow.up")}
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets {store.delete(store.recordings[i])}
                    }
                }
            }
            .navigationTitle("Voice Recorder")
        }
    }
}
