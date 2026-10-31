#if os(iOS) || os(macOS) || os(visionOS)
import SwiftUI
import AVKit
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
import CoreTransferable
import UIKit

// PhotosPicker exports a temporary video file. Make our own copy before the picker
// releases the original URL; no full-length video is loaded into application memory.
private struct SelectedLibraryVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "-" + received.file.lastPathComponent)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return SelectedLibraryVideo(url: destination)
        }
    }
}
#endif

struct LocalMediaView: View {
    @State private var selectingFile = false
    @State private var player: AVPlayer?
    @State private var fileName = "No media selected."
    @State private var scopedURL: URL?
    @State private var temporaryVideoURL: URL?
    @State private var stillImage: Image?
    @State private var gifData: Data?
    @State private var isAudio = false
    @State private var errorMessage: String?
    #if os(iOS)
    @State private var librarySelection: PhotosPickerItem?
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Label("ItamarOS Player", systemImage: "play.rectangle.fill")
                        .font(.title.bold())

                    if let gifData {
                        AnimatedGIFView(data: gifData)
                            .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 420)
                            .accessibilityLabel("Animated GIF")
                    } else if let stillImage {
                        stillImage
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 420)
                            .accessibilityLabel("Selected image")
                    } else if let player, !isAudio {
                        VideoPlayer(player: player)
                            .frame(minHeight: 230)
                    } else if let player, isAudio {
                        VStack(spacing: 18) {
                            Image(systemName: "waveform")
                                .font(.system(size: 54))
                            HStack {
                                Button("Play") { player.play() }
                                Button("Pause") { player.pause() }
                                Button("Restart") {
                                    player.seek(to: .zero)
                                    player.play()
                                }
                            }
                        }
                        .padding()
                    } else {
                        ContentUnavailableView("Choose a photo, GIF, video or audio file", systemImage: "photo.on.rectangle.angled")
                    }

                    Text(fileName)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Button {
                        selectingFile = true
                    } label: {
                        Label("Choose from Files", systemImage: "folder")
                    }
                    .buttonStyle(.borderedProminent)

                    #if os(iOS)
                    PhotosPicker(selection: $librarySelection,
                                 matching: .any(of: [.images, .videos])) {
                        Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.bordered)
                    #endif

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Text("Still images and animated GIFs are displayed locally (GIF via ImageIO). Audio and video use Apple's AVKit. Supported formats depend on the device and codecs.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("Player")
            .fileImporter(
                isPresented: $selectingFile,
                allowedContentTypes: [.image, .gif, .movie, .audio, .mpeg4Movie],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        openFile(url)
                    }
                case .failure(let error):
                    errorMessage = "Unable to open the file: \(error.localizedDescription)"
                }
            }
            #if os(iOS)
            .onChange(of: librarySelection) { _, selection in
                guard let selection else { return }
                Task { await openPhotoLibraryItem(selection) }
            }
            #endif
            .onDisappear {
                player?.pause()
                scopedURL?.stopAccessingSecurityScopedResource()
                scopedURL = nil
            }
        }
    }

    private func releasePrevious() {
        player?.pause()
        player = nil
        stillImage = nil
        gifData = nil
        isAudio = false
        errorMessage = nil
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
        if let temporaryVideoURL {
            try? FileManager.default.removeItem(at: temporaryVideoURL)
            self.temporaryVideoURL = nil
        }
    }

    private func showImage(data: Data, name: String) {
        releasePrevious()
        if data.starts(with: Data("GIF87a".utf8)) || data.starts(with: Data("GIF89a".utf8)) {
            guard data.count <= 18 * 1024 * 1024 else {
                errorMessage = "This GIF is too large to animate safely (18 MB maximum)."
                return
            }
            gifData = data
            fileName = name
            return
        }
        #if os(macOS)
        guard let picture = NSImage(data: data) else {
            errorMessage = "This image format could not be opened."
            return
        }
        stillImage = Image(nsImage: picture)
        #else
        guard let picture = UIImage(data: data) else {
            errorMessage = "This image format could not be opened."
            return
        }
        stillImage = Image(uiImage: picture)
        #endif
        fileName = name
    }

    private func openFile(_ url: URL) {
        releasePrevious()
        let granted = url.startAccessingSecurityScopedResource()
        scopedURL = granted ? url : nil

        let type = UTType(filenameExtension: url.pathExtension.lowercased())
        if type?.conforms(to: .image) == true {
            do {
                let data = try Data(contentsOf: url)
                showImage(data: data, name: url.lastPathComponent)
            } catch {
                errorMessage = "Unable to read the image: \(error.localizedDescription)"
            }
        } else if type?.conforms(to: .audio) == true || type?.conforms(to: .movie) == true
                    || type?.conforms(to: .video) == true {
            isAudio = type?.conforms(to: .audio) == true
            fileName = url.lastPathComponent
            player = AVPlayer(url: url)
            player?.play()
        } else {
            errorMessage = "Unsupported media format. Choose an image, audio or video file."
        }
    }

    #if os(iOS)
    @MainActor
    private func openPhotoLibraryItem(_ item: PhotosPickerItem) async {
        do {
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) }) {
                guard let movie = try await item.loadTransferable(type: SelectedLibraryVideo.self) else {
                    errorMessage = "The selected video is not available."
                    return
                }
                releasePrevious()
                temporaryVideoURL = movie.url
                fileName = "Video from Photos"
                player = AVPlayer(url: movie.url)
                player?.play()
            } else {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    errorMessage = "The selected photo is not available."
                    return
                }
                showImage(data: data, name: "Photo from Photos")
            }
        } catch {
            errorMessage = "Unable to load Photos item: \(error.localizedDescription)"
        }
    }
    #endif
}
#endif
