#if os(iOS) || os(macOS) || os(visionOS)
import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct LocalMediaView: View {
    @State private var selectingFile = false
    @State private var player: AVPlayer?
    @State private var fileName = "No local media selected."
    @State private var scopedURL: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Label("Native media player", systemImage: "play.rectangle.fill")
                    .font(.title.bold())
                if let player {
                    VideoPlayer(player: player)
                        .frame(minHeight: 230)
                } else {
                    ContentUnavailableView("No media", systemImage: "film")
                }
                Text(fileName)
                    .foregroundStyle(.secondary)
                Button("Choose media in Files") { selectingFile = true }
                    .buttonStyle(.borderedProminent)
                Text("Video playback uses Apple's AVKit, not a website. Available formats depend on the iPhone or iPad.")
                    .font(.footnote)
            }
            .padding()
            .navigationTitle("Player")
            .fileImporter(isPresented: $selectingFile,
                          allowedContentTypes: [.movie, .audio, .mpeg4Movie], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    scopedURL?.stopAccessingSecurityScopedResource()
                    let scoped = url.startAccessingSecurityScopedResource()
                    scopedURL = scoped ? url : nil
                    fileName = url.lastPathComponent
                    player = AVPlayer(url: url)
                    player?.play()
                case .failure:
                    fileName = "Unable to open the selected file."
                }
            }
            .onDisappear {
                player?.pause()
                scopedURL?.stopAccessingSecurityScopedResource()
                scopedURL = nil
            }
        }
    }
}
#endif
