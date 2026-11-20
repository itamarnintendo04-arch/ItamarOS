import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @AppStorage("backupAcknowledged") private var backupAcknowledged = false
    @State private var appName = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var iconImage: UIImage?
    @State private var exportedImage: UIImage?
    @State private var showingShare = false

    var body: some View {
        NavigationStack {
            Form {\n                Section("Wallpapers") {\n                    NavigationLink("Tendies Wallpapers") { TendiesLibraryView() }\n                }
                Section("iCloud Backup") {
                    Label("Back up your iPhone before making changes.", systemImage: "icloud")
                    Text("Settings → Your Name → iCloud → iCloud Backup → Back Up Now")
                        .font(.footnote)
                    Toggle("I understand the backup recommendation", isOn: $backupAcknowledged)
                }
                Section("Customize Home Screen Shortcut") {
                    TextField("Custom app name", text: $appName)
                    PhotosPicker("Choose icon image", selection: $selectedPhoto, matching: .images)
                    if let iconImage {
                        Image(uiImage: iconImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 110, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                    }
                    Button("Export Icon PNG") {
                        guard let iconImage else { return }
                        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 1024))
                        exportedImage = renderer.image { _ in
                            let size = iconImage.size
                            guard size.width > 0, size.height > 0 else { return }
                            let scale = max(1024 / size.width, 1024 / size.height)
                            let w = size.width * scale, h = size.height * scale
                            iconImage.draw(in: CGRect(x: (1024-w)/2, y: (1024-h)/2, width: w, height: h))
                        }
                        showingShare = true
                    }
                    .disabled(!backupAcknowledged || iconImage == nil)
                }
                Section("Apply on iPhone") {
                    Text("1. Open Apple's Shortcuts app.")
                    Text("2. Create a shortcut using the Open App action and choose the app.")
                    Text("3. Choose Add to Home Screen, enter your custom name, and select the exported icon.")
                    Text("This creates a shortcut. It does not change the original app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("iPhone Studio")
            .task(id: selectedPhoto) {
                guard let data = try? await selectedPhoto?.loadTransferable(type: Data.self) else { return }
                iconImage = UIImage(data: data)
            }
            .sheet(isPresented: $showingShare) {
                if let exportedImage { ShareSheet(items: [exportedImage]) }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
