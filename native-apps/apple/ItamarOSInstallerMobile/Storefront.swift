import SwiftUI

/// Native app-store interface: Discover, Apps, Games, Updates, Library, Sources.
/// The official source contains ALL eleven ItamarOS iOS apps, including tools,
/// utilities, creative apps, the authenticator and the installer, not only games.
struct StorefrontScreen: View {
    @StateObject private var store = ItamarStore()
    @State private var section: StoreSection = .discover
    @State private var activeItem: StoreItem?
    @State private var newSource = ""
    @State private var scanningSourceQR = false
    @State private var pendingSource = ""
    @State private var confirmCommunitySource = false

    private let tiles = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    heading
                    sectionPicker
                    if section == .sources {
                        sourcesView
                    } else if section == .updates {
                        updatesView
                    } else if section == .library {
                        libraryView
                    } else {
                        discoveryView
                    }
                    Text("Unsigned developer apps require valid Apple signing and supported distribution. Community sources are not reviewed by ItamarOS.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("ItamarOS Store")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $store.query, prompt: "Search apps, games or sources")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await store.refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.loading)
                }
            }
            .task { await store.refresh() }
            .sheet(item: $activeItem) { app in
                StoreAppDetails(item: app, store: store)
            }
            .alert("Store", isPresented: Binding(
                get: { store.error != nil },
                set: { if !$0 { store.error = nil } }
            )) {
                Button("OK") { store.error = nil }
            } message: {
                Text(store.error ?? "")
            }
            .sheet(isPresented: $scanningSourceQR) {
                NavigationStack {
                    SourceQRScanner { url in
                        newSource = url
                        scanningSourceQR = false
                    }
                    .navigationTitle("Scan Source QR")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Cancel") { scanningSourceQR = false }
                        }
                    }
                }
            }
            .alert("Add Community Source", isPresented: $confirmCommunitySource) {
                Button("Cancel", role: .cancel) { pendingSource = "" }
                Button("Add Source") {
                    let url = pendingSource
                    pendingSource = ""
                    newSource = ""
                    Task { await store.addSource(url) }
                }
            } message: {
                Text("Apps from third-party sources are not verified by ItamarOS. Only add catalogs from publishers you trust. No certificates or P12 passwords will be shared.")
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .foregroundStyle(.cyan)
                Text("THE ITAMAROS APP COLLECTION")
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }
            Text(section == .discover ? "Today" : section.rawValue)
                .font(.system(size: 35, weight: .bold, design: .rounded))
            Text(section == .sources
                 ? "Your official and community app catalogs"
                 : "Discover original apps, creative tools and games")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StoreSection.allCases) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { section = item }
                    } label: {
                        Label(item.rawValue, systemImage: item.symbol)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .foregroundStyle(section == item ? Color.white : Color.primary)
                            .background(section == item ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground),
                                        in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var discoveryView: some View {
        VStack(alignment: .leading, spacing: 20) {
            if section == .discover && !store.items.isEmpty {
                let featured = store.items.first(where: { $0.official && !$0.isGame }) ?? store.items[0]
                Button { activeItem = featured } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("FEATURED APP").font(.caption.weight(.bold)).tracking(1.2)
                            Text(featured.name).font(.title2.weight(.bold))
                            Text(featured.summary).font(.footnote).lineLimit(3)
                            Label("See Details", systemImage: "chevron.right.circle.fill")
                                .font(.caption.weight(.medium))
                                .padding(.top, 3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        StoreAppIcon(url: featured.iconURL, game: featured.isGame, dimension: 94)
                    }
                    .foregroundStyle(.white)
                    .padding(20)
                    .background(
                        LinearGradient(colors: [.indigo, .blue, .cyan.opacity(0.7)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 22)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }
            if store.loading && store.items.isEmpty {
                ProgressView("Loading app sources…")
                    .frame(maxWidth: .infinity)
                    .padding(36)
            } else if store.items.isEmpty {
                ContentUnavailableView("No apps found", systemImage: "square.stack.3d.up.slash",
                                       description: Text("Refresh the official catalog or check the Sources tab."))
            } else {
                if section == .discover {
                    sectionHeader("Official ItamarOS", subtitle: "Games and everyday apps from the main repository")
                    appGrid(store.apps(for: .discover).filter(\.official))
                    let community = store.apps(for: .discover).filter { !$0.official }
                    if !community.isEmpty {
                        sectionHeader("Community Sources", subtitle: "Unverified third-party applications")
                        appGrid(community)
                    }
                } else {
                    sectionHeader(section == .games ? "Games" : "Apps & Utilities",
                                  subtitle: section == .games ? "Play something new" : "Tools, creative apps and more")
                    appGrid(store.apps(for: section))
                }
            }
        }
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.bold())
            Text(subtitle).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
    }

    private func appGrid(_ apps: [StoreItem]) -> some View {
        LazyVGrid(columns: tiles, spacing: 14) {
            ForEach(apps) { item in
                Button { activeItem = item } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            StoreAppIcon(url: item.iconURL, game: item.isGame, dimension: 70)
                            Spacer()
                            Image(systemName: item.official ? "checkmark.seal.fill" : "exclamationmark.circle")
                                .foregroundStyle(item.official ? .blue : .orange)
                        }
                        Text(item.name)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(item.category + " · " + item.developer)
                            .font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(item.summary).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(2)
                        Text(store.downloaded[item.id] != nil ? "IN LIBRARY" : "GET")
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.13), in: Capsule())
                    }
                    .frame(maxWidth: .infinity, minHeight: 181, alignment: .topLeading)
                    .padding(13)
                    .background(Color(uiColor: .secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private var updatesView: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Your downloads", subtitle: "Check official releases and download newer IPA versions")
            let downloaded = store.apps(for: .updates)
            if downloaded.isEmpty {
                ContentUnavailableView("No downloaded apps yet", systemImage: "arrow.clockwise.circle",
                    description: Text("Download an IPA from an app page. iOS installation and updates must still follow Apple's requirements."))
            } else {
                ForEach(downloaded) { item in
                    Button { activeItem = item } label: {
                        StoreAppLine(item: item, action: "Check Update")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
            }
            Text("Updates are checked from each source's catalog version. A newer listing does not prove that an app is installed or up to date on the Home Screen.")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 18)
        }
    }

    private var libraryView: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Your Library", subtitle: "IPAs downloaded into ItamarOS Installer")
            let downloaded = store.apps(for: .library)
            if downloaded.isEmpty {
                ContentUnavailableView("Your library is empty", systemImage: "square.stack",
                    description: Text("Downloaded IPA files appear here. iOS app installations are not automatically detected."))
            } else {
                ForEach(downloaded) { item in
                    Button { activeItem = item } label: {
                        StoreAppLine(item: item, action: "Open")
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private var sourcesView: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionHeader("App Sources", subtitle: "The official source includes ordinary apps and games")
            ForEach(store.sources) { source in
                HStack(spacing: 12) {
                    Image(systemName: source.official ? "checkmark.shield.fill" : "books.vertical.fill")
                        .font(.title2)
                        .foregroundStyle(source.official ? .blue : .orange)
                        .frame(width: 38)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(source.name).font(.subheadline.bold())
                            if source.official {
                                Text("OFFICIAL").font(.caption2.bold()).foregroundStyle(.blue)
                            }
                        }
                        Text(source.url)
                            .font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(2)
                        Text("\(store.items.filter { $0.sourceID == source.id }.count) apps")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !source.official {
                        VStack {
                            Toggle("Enable", isOn: Binding(
                                get: { source.enabled },
                                set: { store.setEnabled(source.id, $0) }
                            )).labelsHidden()
                            Button("Remove", role: .destructive) {
                                store.removeSource(source.id)
                            }
                            .font(.caption)
                        }
                    } else {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(15)
                .background(Color(uiColor: .secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 17))
                .padding(.horizontal, 16)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Add a Source").font(.headline)
                TextField("https://example.com/itamaros-source.json", text: $newSource)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button {
                        pendingSource = newSource
                        confirmCommunitySource = true
                    } label: {
                        Label("Add Source", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        scanningSourceQR = true
                    } label: {
                        Label("Scan QR", systemImage: "qrcode.viewfinder")
                    }
                    .buttonStyle(.bordered)
                }
                Text("Community sources use HTTPS JSON catalogs. They are not endorsed or security-reviewed by ItamarOS. App files are checked for their stated Bundle ID before being saved. Certificates and passwords are never sent to sources.")
                    .font(.footnote).foregroundStyle(.secondary)
                Link("Source format and examples",
                     destination: URL(string: "https://github.com/itamarnintendo04-arch/ItamarOS/blob/main/catalog/SOURCE_FORMAT.md")!)
                    .font(.footnote)
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 16)
        }
    }
}

private struct StoreAppLine: View {
    let item: StoreItem
    let action: String

    var body: some View {
        HStack(spacing: 12) {
            StoreAppIcon(url: item.iconURL, game: item.isGame, dimension: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.headline)
                Text(item.sourceName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(action).font(.caption.bold())
                .foregroundStyle(.blue)
                .padding(.horizontal, 11).padding(.vertical, 8)
                .background(.blue.opacity(0.12), in: Capsule())
        }
        .padding(11)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 15))
    }
}

private struct StoreAppIcon: View {
    let url: URL?
    let game: Bool
    let dimension: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [.indigo, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: game ? "gamecontroller.fill" : "app.fill")
                        .font(.system(size: dimension * 0.41))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: dimension, height: dimension)
        .clipShape(RoundedRectangle(cornerRadius: dimension * 0.22))
    }
}

private struct StoreAppDetails: View {
    @EnvironmentObject private var companion: LANCompanionModel
    let item: StoreItem
    @ObservedObject var store: ItamarStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingSigner = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        StoreAppIcon(url: item.iconURL, game: item.isGame, dimension: 104)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.name).font(.title2.bold())
                            Text(item.developer).font(.subheadline).foregroundStyle(.secondary)
                            Label(item.official ? "Official ItamarOS" : "Unverified community source",
                                  systemImage: item.official ? "checkmark.seal.fill" : "exclamationmark.shield")
                                .font(.caption)
                                .foregroundStyle(item.official ? .blue : .orange)
                            Text(item.category).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 12) {
                        Button {
                            Task { await store.download(item) }
                        } label: {
                            Label(store.downloadingID == item.id ? "Downloading…" : "Get IPA",
                                  systemImage: "arrow.down.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.downloadingID != nil)
                        if let file = store.downloaded[item.id] {
                            ShareLink(item: file) {
                                Label("Share IPA", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    if item.official {
                        Button {
                            if let app = companion.apps.first(where: { $0.id == item.appID }) {
                                Task { await companion.requestInstall(app) }
                            } else {
                                companion.state = "ITA-404: This app is not available from the paired computer's official catalog."
                            }
                        } label: {
                            Label("Install with paired computer", systemImage: "iphone.and.arrow.forward")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!companion.paired || !companion.activeRequest.isEmpty)
                        Text(companion.paired
                             ? "The paired computer must approve the request. Signing and a compatible iPhone connection are required."
                             : "ITAMAROSERVER CANT BE FOUND (ITA-001). Pair the iPhone in the Wi-Fi tab first.")
                            .font(.footnote).foregroundStyle(.secondary)
                        if !companion.state.isEmpty {
                            Text(companion.state).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("Downloading is not installing. An unsigned IPA must be signed with an authorized certificate and installed through an Apple-supported method.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let file = store.downloaded[item.id] {
                        Label("IPA downloaded and Bundle ID checked", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.subheadline)
                        Button {
                            showingSigner = true
                        } label: {
                            Label("Open signing WebView", systemImage: "signature")
                        }
                    }
                    Divider()
                    Text("About this App").font(.title3.bold())
                    Text(item.summary).font(.body)
                    HStack {
                        fact("Version", value: item.version)
                        fact("Source", value: item.sourceName)
                        fact("Bundle ID", value: item.bundleID)
                    }
                    if !item.screenshots.isEmpty {
                        Text("Screenshots").font(.title3.bold())
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(item.screenshots, id: \.self) { url in
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image { image.resizable().scaledToFit() }
                                        else { RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.2)) }
                                    }
                                    .frame(width: 195, height: 330)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            }
                        }
                    }
                    if let releaseURL = item.releaseURL {
                        Link("View Release", destination: releaseURL)
                    }
                    if !item.official {
                        Label("Third-party listing: review the publisher and permissions before trusting any downloaded IPA.",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }
                .padding()
            }
            .navigationTitle("App Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingSigner) {
                EmbeddedIPASignerView(appName: item.name, originalIPA: store.downloaded[item.id])
            }
        }
    }

    private func fact(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.medium)).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
