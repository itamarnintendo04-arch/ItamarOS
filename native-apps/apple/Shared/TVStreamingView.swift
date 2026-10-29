#if os(tvOS)
import SwiftUI

private struct TVService: Identifiable {
    let id: String
    let title: String
    let region: String?
}

struct TVStreamingView: View {
    @State private var selected: TVService?
    @State private var regionOverride = "auto"

    private var country: String {
        if regionOverride != "auto" { return regionOverride }
        if TimeZone.current.identifier == "Asia/Jerusalem" { return "IL" }
        return Locale.current.region?.identifier ?? "Unknown"
    }

    private var providers: [TVService] {
        let global = [
            TVService(id: "netflix", title: "Netflix", region: nil),
            TVService(id: "disney", title: "Disney+", region: nil),
            TVService(id: "apple-tv", title: "Apple TV", region: nil),
            TVService(id: "youtube", title: "YouTube", region: nil),
            TVService(id: "prime", title: "Prime Video", region: nil)
        ]
        let local = [
            TVService(id: "kan", title: "כאן BOX", region: "IL"),
            TVService(id: "yes", title: "yes+", region: "IL"),
            TVService(id: "hot", title: "HOT", region: "IL"),
            TVService(id: "hulu", title: "Hulu", region: "US"),
            TVService(id: "peacock", title: "Peacock", region: "US")
        ]
        return global + local.filter { $0.region == country }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("TV Streaming")
                        .font(.largeTitle.bold())
                    Text("Estimated country: \(country). Time zone and device region are approximate; no GPS is used.")
                        .foregroundStyle(.secondary)
                    Picker("Region", selection: $regionOverride) {
                        Text("Automatic").tag("auto")
                        Text("Israel").tag("IL")
                        Text("United States").tag("US")
                        Text("Other").tag("Other")
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 18) {
                        ForEach(providers) { provider in
                            Button {
                                selected = provider
                            } label: {
                                Text(provider.title)
                                    .font(.title3.bold())
                                    .frame(maxWidth: .infinity, minHeight: 105)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    Text("tvOS does not provide a general-purpose API for opening arbitrary installed third-party TV apps. Use Apple TV Home or the App Store to open each service.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(32)
            }
            .navigationTitle("Streaming")
            .alert("Open the official application", isPresented: Binding(
                get: { selected != nil },
                set: { if !$0 { selected = nil } }
            )) {
                Button("OK", role: .cancel) { selected = nil }
            } message: {
                Text("To watch \(selected?.title ?? "this service"), open its official app from Apple TV Home. ItamarOS does not bypass subscriptions, DRM or installation restrictions.")
            }
        }
    }
}
#endif
