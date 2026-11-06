import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers

@main
struct ItamarCutApp: App {
    var body: some Scene {
        WindowGroup { ItamarCutEditor() }
    }
}

struct ItamarCutClip: Identifiable {
    let id = UUID()
    let url: URL
    var trimStart: Double = 0
    var trimEnd: Double?
    var muted = false
    var speed: Double = 1
}

@MainActor
final class ItamarCutProject: ObservableObject {
    @Published var clips: [ItamarCutClip] = []
    @Published var selectedID: UUID?
    @Published var player: AVPlayer?
    @Published var errorMessage: String?
    @Published var exporting = false
    @Published var exportURL: URL?

    var selectedIndex: Int? { clips.firstIndex { $0.id == selectedID } }
    func add(_ url: URL) {
        clips.append(ItamarCutClip(url: url))
        selectedID = clips.last?.id
        preview()
    }
    func preview() {
        guard let i=selectedIndex else {return}
        let clip=clips[i]
        let item=AVPlayerItem(url:clip.url)
        player=AVPlayer(playerItem:item)
        player?.seek(to:CMTime(seconds:clip.trimStart,preferredTimescale:600))
    }
    func move(_ offset: Int) {
        guard let i=selectedIndex else {return}
        let j=i+offset
        guard clips.indices.contains(j) else {return}
        clips.swapAt(i,j)
    }
    func remove() {
        guard let i=selectedIndex else {return}
        clips.remove(at:i)
        selectedID=clips.first?.id
        preview()
    }
    func export() async {
        guard !clips.isEmpty else {return}
        exporting=true
        defer {exporting=false}
        do {
            let composition=AVMutableComposition()
            guard let videoTrack=composition.addMutableTrack(withMediaType:.video,preferredTrackID:kCMPersistentTrackID_Invalid) else {throw ExportError.noTrack}
            let audioTrack=composition.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid)
            var cursor=CMTime.zero
            for clip in clips {
                let asset=AVURLAsset(url:clip.url)
                guard let sourceVideo=try await asset.loadTracks(withMediaType:.video).first else {continue}
                let duration=try await asset.load(.duration)
                let start=CMTime(seconds:clip.trimStart,preferredTimescale:600)
                let end=CMTime(seconds:clip.trimEnd ?? duration.seconds,preferredTimescale:600)
                let range=CMTimeRange(start:start,duration:CMTimeSubtract(end,start))
                guard range.duration.seconds > 0 else {continue}
                try videoTrack.insertTimeRange(range,of:sourceVideo,at:cursor)
                if !clip.muted,let sourceAudio=try await asset.loadTracks(withMediaType:.audio).first {
                    try audioTrack?.insertTimeRange(range,of:sourceAudio,at:cursor)
                }
                let scaled=CMTimeMultiplyByFloat64(range.duration,multiplier:1/clip.speed)
                videoTrack.scaleTimeRange(CMTimeRange(start:cursor,duration:range.duration),toDuration:scaled)
                if !clip.muted {audioTrack?.scaleTimeRange(CMTimeRange(start:cursor,duration:range.duration),toDuration:scaled)}
                cursor=CMTimeAdd(cursor,scaled)
            }
            guard cursor.seconds > 0 else {throw ExportError.noTrack}
            let target=FileManager.default.temporaryDirectory.appendingPathComponent("ItamarCut-\(UUID().uuidString).mov")
            guard let session=AVAssetExportSession(asset:composition,presetName:AVAssetExportPresetHighestQuality) else {throw ExportError.noExporter}
            session.outputURL=target
            session.outputFileType=.mov
            await session.export()
            if let err=session.error {throw err}
            guard session.status == .completed else {throw ExportError.failed}
            exportURL=target
        } catch {errorMessage=error.localizedDescription}
    }
    enum ExportError: LocalizedError {
        case noTrack,noExporter,failed
        var errorDescription:String? {"Unable to export this project."}
    }
}

struct ItamarCutEditor: View {
    @StateObject private var project=ItamarCutProject()
    @State private var pickerItem: PhotosPickerItem?
    @State private var start:Double=0
    @State private var end:Double=0
    var body: some View {
        NavigationStack {
            VStack(spacing:12) {
                ZStack {
                    Color.black
                    if let player=project.player {
                        VideoPlayer(player:player)
                    } else {
                        ContentUnavailableView("New project",systemImage:"film.stack",description:Text("Import a video to start editing."))
                            .foregroundStyle(.white)
                    }
                }
                .frame(height:260)
                .clipShape(RoundedRectangle(cornerRadius:12))
                ScrollView(.horizontal) {
                    HStack(spacing:8) {
                        ForEach(project.clips) { clip in
                            Button {
                                project.selectedID=clip.id
                                project.preview()
                            } label: {
                                VStack {
                                    Image(systemName:"film.fill")
                                    Text(clip.url.lastPathComponent).lineLimit(1)
                                }
                                .frame(width:120,height:78)
                                .background(project.selectedID == clip.id ? Color.purple.opacity(0.35) : Color.gray.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius:10))
                            }
                        }
                    }
                }
                .padding(.horizontal)
                HStack {
                    PhotosPicker(selection:$pickerItem,matching:.videos) {
                        Label("Import video",systemImage:"plus")
                    }
                    Spacer()
                    Button {project.move(-1)} label:{Image(systemName:"arrow.left")}
                    Button {project.move(1)} label:{Image(systemName:"arrow.right")}
                    Button(role:.destructive) {project.remove()} label:{Image(systemName:"trash")}
                }
                .padding(.horizontal)
                if let i=project.selectedIndex {
                    Form {
                        Section("Clip tools") {
                            Toggle("Mute clip",isOn:$project.clips[i].muted)
                            HStack {
                                Text("Speed")
                                Slider(value:$project.clips[i].speed,in:0.25...3,step:0.25)
                                Text("\(project.clips[i].speed,specifier:"%.2f")×")
                            }
                            HStack {
                                Text("Trim start")
                                TextField("Seconds",value:$project.clips[i].trimStart,format:.number)
                                    .keyboardType(.decimalPad)
                            }
                            HStack {
                                Text("Trim end")
                                TextField("End (seconds)",value:$project.clips[i].trimEnd,format:.number)
                                    .keyboardType(.decimalPad)
                            }
                        }
                    }
                }
                Button {
                    Task {await project.export()}
                } label: {
                    Label(project.exporting ? "Exporting..." : "Export movie",systemImage:"square.and.arrow.up")
                        .frame(maxWidth:.infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(project.exporting || project.clips.isEmpty)
                if let url=project.exportURL {
                    ShareLink(item:url) {Label("Share exported video",systemImage:"square.and.arrow.up")}
                }
                if let message=project.errorMessage {
                    Text(message).font(.caption).foregroundStyle(.red)
                }
            }
            .navigationTitle("ItamarCut")
            .onChange(of:pickerItem) { _,item in
                Task {
                    guard let item,let data=try? await item.loadTransferable(type:Data.self) else {return}
                    let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".mov")
                    do {
                        try data.write(to:url)
                        project.add(url)
                    } catch {project.errorMessage=error.localizedDescription}
                }
            }
        }
        .tint(.purple)
    }
}
