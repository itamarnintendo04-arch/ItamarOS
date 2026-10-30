#if os(tvOS)
import SwiftUI

// Apple TV requires App Store-authorized installation and does not expose a general
// third-party API to install arbitrary applications. This catalog never pretends to install.
struct TVStoreView: View {
    @State private var category = "Apps"
    @State private var selected: String?
    private let apps = ["VLC", "Plex", "Infuse", "Spotify", "YouTube"]
    private let games = ["Crossy Road", "Asphalt 8", "Beach Buggy Racing"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("ItamarOS TV Store").font(.largeTitle.bold())
                    Text("Discover apps and games for Apple TV. Downloads and compatibility checks take place in Apple's built-in App Store, not in ItamarOS.")
                        .foregroundStyle(.secondary)
                    Picker("Category", selection: $category) {
                        Text("Apps").tag("Apps")
                        Text("Games").tag("Games")
                    }
                    .pickerStyle(.segmented)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                        ForEach(category == "Apps" ? apps : games, id: \.self) { name in
                            Button(name) { selected = name }
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity, minHeight: 110)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    Text("To install: open the official App Store on Apple TV, search the selected title and choose Get if it is available for your device and region. There is no background installation or unsupported sideloading.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(36)
            }
            .navigationTitle("Store")
            .alert("Find in the Apple TV App Store", isPresented: Binding(
                get: { selected != nil }, set: { if !$0 { selected = nil } }
            )) {
                Button("OK", role: .cancel) { selected = nil }
            } message: {
                Text("Search for \(selected ?? "this app") in your Apple TV App Store. Only Apple can confirm availability and install it on this device.")
            }
        }
    }
}
#endif
