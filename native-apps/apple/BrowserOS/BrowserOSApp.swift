import SwiftUI
import WebKit
import UniformTypeIdentifiers

@main
struct BrowserOSApp: App {
    var body: some Scene {
        WindowGroup {
            BrowserHome()
                .tint(Color(red: 0.25, green: 0.83, blue: 0.95))
        }
    }
}

struct BrowserTab: Identifiable {
    let id = UUID()
    var url: URL?
    var title: String = "New Tab"
    var privateMode = false
}

@MainActor
final class BrowserModel: ObservableObject {
    @Published var tabs: [BrowserTab] = [BrowserTab()]
    @Published var selected = 0
    @Published var address = ""
    @Published var title = "BrowserOS"
    @Published var progress = 0.0
    @Published var loading = false
    @Published var canBack = false
    @Published var canForward = false
    @Published var bookmarks: [String] = UserDefaults.standard.stringArray(forKey: "browseros.bookmarks") ?? []
    @Published var history: [String] = UserDefaults.standard.stringArray(forKey: "browseros.history") ?? []
    @Published var showTabs = false
    @Published var showBookmarks = false
    @Published var showHistory = false
    @Published var error = ""
    private var webviews: [UUID: WKWebView] = [:]
    private var observers: [UUID: BrowserObserver] = [:]

    var current: BrowserTab { tabs[selected] }
    var currentWebView: WKWebView {
        let tab = current
        if let view = webviews[tab.id] { return view }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = tab.privateMode ? .nonPersistent() : .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.allowsBackForwardNavigationGestures = true
        view.isInspectable = false
        let delegate = BrowserObserver(model: self, tabID: tab.id)
        view.navigationDelegate = delegate
        view.uiDelegate = delegate
        observers[tab.id] = delegate
        webviews[tab.id] = view
        if let url = tab.url { view.load(URLRequest(url: url)) }
        return view
    }

    func navigate(_ text: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let candidate: URL?
        if let parsed = URL(string: value), ["https", "http"].contains(parsed.scheme?.lowercased() ?? ""), parsed.host != nil {
            candidate = parsed
        } else if !value.contains(" ") && value.contains("."),
                  let url = URL(string: "https://" + value), url.host != nil {
            candidate = url
        } else {
            var parts = URLComponents(string: "https://www.google.com/search")
            parts?.queryItems = [URLQueryItem(name: "q", value: value)]
            candidate = parts?.url
        }
        guard let url = candidate else { return }
        address = url.absoluteString
        tabs[selected].url = url
        currentWebView.load(URLRequest(url: url))
    }

    func newTab(privateMode: Bool = false) {
        tabs.append(BrowserTab(privateMode: privateMode))
        selected = tabs.count - 1
        address = ""
        title = privateMode ? "Private Tab" : "BrowserOS"
        loading = false
        progress = 0
        canBack = false
        canForward = false
        showTabs = false
    }

    func select(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        selected = index
        address = currentWebView.url?.absoluteString ?? ""
        title = currentWebView.title ?? "BrowserOS"
        canBack = currentWebView.canGoBack
        canForward = currentWebView.canGoForward
        loading = currentWebView.isLoading
        progress = currentWebView.estimatedProgress
        showTabs = false
    }

    func close(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        let tab = tabs.remove(at: index)
        webviews[tab.id]?.stopLoading()
        webviews[tab.id]?.navigationDelegate = nil
        webviews[tab.id]?.uiDelegate = nil
        webviews.removeValue(forKey: tab.id)
        observers.removeValue(forKey: tab.id)
        if tabs.isEmpty { tabs = [BrowserTab()] }
        select(min(selected >= index ? max(0, selected - 1) : selected, tabs.count - 1))
    }

    func addBookmark() {
        guard let url = currentWebView.url?.absoluteString, !bookmarks.contains(url) else { return }
        bookmarks.insert(url, at: 0)
        UserDefaults.standard.set(bookmarks, forKey: "browseros.bookmarks")
    }

    func removeBookmark(_ url: String) {
        bookmarks.removeAll { $0 == url }
        UserDefaults.standard.set(bookmarks, forKey: "browseros.bookmarks")
    }

    func visited(_ url: URL, tabID: UUID, title pageTitle: String?) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[index].url = url
        tabs[index].title = pageTitle ?? url.host ?? "Page"
        if !tabs[index].privateMode {
            history.removeAll { $0 == url.absoluteString }
            history.insert(url.absoluteString, at: 0)
            history = Array(history.prefix(250))
            UserDefaults.standard.set(history, forKey: "browseros.history")
        }
        if index == selected { refresh(tabID: tabID) }
    }

    func refresh(tabID: UUID) {
        guard tabs.indices.contains(selected), tabs[selected].id == tabID,
              let view = webviews[tabID] else { return }
        address = view.url?.absoluteString ?? ""
        title = view.title ?? "BrowserOS"
        canBack = view.canGoBack
        canForward = view.canGoForward
        loading = view.isLoading
        progress = view.estimatedProgress
    }

    func clearHistory() {
        history.removeAll()
        UserDefaults.standard.removeObject(forKey: "browseros.history")
    }

    func clearWebsiteData() {
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast) {}
        clearHistory()
    }
}

final class BrowserObserver: NSObject, WKNavigationDelegate, WKUIDelegate {
    weak var model: BrowserModel?
    let tabID: UUID
    init(model: BrowserModel, tabID: UUID) {
        self.model = model
        self.tabID = tabID
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Task { @MainActor in self.model?.refresh(tabID: self.tabID) }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            if let url = webView.url { self.model?.visited(url, tabID: self.tabID, title: webView.title) }
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.model?.error = error.localizedDescription; self.model?.refresh(tabID: self.tabID) }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in self.model?.error = error.localizedDescription; self.model?.refresh(tabID: self.tabID) }
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if ["http", "https", "about"].contains(url.scheme?.lowercased() ?? "") {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
}

private struct BrowserWebContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct BrowserHome: View {
    @StateObject private var browser = BrowserModel()
    @FocusState private var addressFocused: Bool
    @State private var showSettings = false
    @State private var showShare = false
    private let bg = Color(red: 0.035, green: 0.065, blue: 0.12)
    private let surface = Color(red: 0.095, green: 0.14, blue: 0.23)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if browser.loading {
                    ProgressView(value: browser.progress)
                        .tint(.cyan)
                }
                if browser.current.url == nil && browser.currentWebView.url == nil {
                    startPage
                } else {
                    BrowserWebContainer(webView: browser.currentWebView)
                        .id(browser.current.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                toolbar
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $browser.showTabs) { tabsSheet }
        .sheet(isPresented: $browser.showBookmarks) { urlList(title: "Bookmarks", urls: browser.bookmarks, clear: nil) }
        .sheet(isPresented: $browser.showHistory) { urlList(title: "History", urls: browser.history, clear: browser.clearHistory) }
        .sheet(isPresented: $showSettings) { settingsSheet }
        .sheet(isPresented: $showShare) {
            if let url = browser.currentWebView.url {
                ShareSheet(items: [url])
            }
        }
        .alert("Unable to load page", isPresented: Binding(
            get: { !browser.error.isEmpty },
            set: { if !$0 { browser.error = "" } }
        )) { Button("OK") { browser.error = "" } } message: { Text(browser.error) }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe.americas.fill")
                .font(.title3).foregroundStyle(.cyan)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search or enter URL", text: $browser.address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .focused($addressFocused)
                    .onSubmit { browser.navigate(browser.address); addressFocused = false }
                if !browser.address.isEmpty {
                    Button { browser.address = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 43)
            .background(surface, in: RoundedRectangle(cornerRadius: 14))
            Button { browser.navigate(browser.address); addressFocused = false } label: {
                Image(systemName: "arrow.right.circle.fill").font(.title2)
            }
            .accessibilityLabel("Go")
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .background(bg)
    }

    private var startPage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 45)
                Image(systemName: browser.current.privateMode ? "eye.slash.fill" : "globe.europe.africa.fill")
                    .font(.system(size: 76))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .mint], startPoint: .top, endPoint: .bottom))
                VStack(spacing: 5) {
                    Text(browser.current.privateMode ? "Private Browsing" : "BrowserOS")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                    Text("By ItamarOS").foregroundStyle(.cyan).font(.headline)
                    Text(browser.current.privateMode ? "This tab won't save browsing history." : "Explore the web your way.")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    shortcut("Google", icon: "magnifyingglass", url: "https://www.google.com")
                    shortcut("YouTube", icon: "play.rectangle.fill", url: "https://www.youtube.com")
                    shortcut("Wikipedia", icon: "book.fill", url: "https://www.wikipedia.org")
                }
                .padding(.top, 15)
                if !browser.bookmarks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Favorites").font(.title3.bold())
                        ForEach(browser.bookmarks.prefix(6), id: \.self) { url in
                            Button { browser.navigate(url) } label: {
                                Label(URL(string: url)?.host ?? url, systemImage: "star.fill")
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(13)
                                    .background(surface, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                Spacer(minLength: 30)
            }
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
            .padding(20)
        }
    }

    private func shortcut(_ title: String, icon: String, url: String) -> some View {
        Button { browser.navigate(url) } label: {
            VStack(spacing: 10) {
                Image(systemName: icon).font(.title2)
                Text(title).font(.caption.bold())
            }
            .frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(surface, in: RoundedRectangle(cornerRadius: 17))
        }
    }

    private var toolbar: some View {
        HStack {
            tool("chevron.left", enabled: browser.canBack) { browser.currentWebView.goBack() }
            Spacer()
            tool("chevron.right", enabled: browser.canForward) { browser.currentWebView.goForward() }
            Spacer()
            tool(browser.loading ? "xmark" : "arrow.clockwise") {
                if browser.loading { browser.currentWebView.stopLoading() }
                else { browser.currentWebView.reload() }
            }
            Spacer()
            tool("square.on.square") { browser.showTabs = true }
                .overlay(alignment: .topTrailing) {
                    Text("\(browser.tabs.count)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(3).background(.cyan, in: Circle()).offset(x: 8, y: -5)
                }
            Spacer()
            Menu {
                Button("New tab", systemImage: "plus") { browser.newTab() }
                Button("New private tab", systemImage: "eye.slash") { browser.newTab(privateMode: true) }
                Button("Bookmark this page", systemImage: "star") { browser.addBookmark() }
                Button("Bookmarks", systemImage: "book") { browser.showBookmarks = true }
                Button("History", systemImage: "clock") { browser.showHistory = true }
                Button("Share page", systemImage: "square.and.arrow.up") { showShare = true }
                Button("Settings", systemImage: "gearshape") { showSettings = true }
            } label: { Image(systemName: "ellipsis.circle").font(.title2).frame(width: 40, height: 42) }
        }
        .padding(.horizontal, 25).padding(.vertical, 9)
        .background(bg)
    }

    private func tool(_ symbol: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.title3).frame(width: 40, height: 42) }
            .disabled(!enabled).opacity(enabled ? 1 : 0.3)
    }

    private var tabsSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: 14) {
                    ForEach(Array(browser.tabs.enumerated()), id: \.element.id) { index, tab in
                        Button { browser.select(index) } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: tab.privateMode ? "eye.slash" : "globe")
                                    Spacer()
                                    Button { browser.close(index) } label: {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                                Text(tab.title).font(.headline).lineLimit(2)
                                Text(tab.url?.host ?? "New Tab").font(.caption).lineLimit(1).foregroundStyle(.secondary)
                            }
                            .padding(15).frame(height: 160)
                            .frame(maxWidth: .infinity)
                            .background(index == browser.selected ? Color.cyan.opacity(0.2) : surface,
                                        in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                    }
                }.padding()
            }
            .navigationTitle("Tabs")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Private +") { browser.newTab(privateMode: true) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New +") { browser.newTab() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func urlList(title: String, urls: [String], clear: (() -> Void)?) -> some View {
        NavigationStack {
            List {
                ForEach(urls, id: \.self) { url in
                    Button {
                        browser.navigate(url)
                        browser.showBookmarks = false
                        browser.showHistory = false
                    } label: {
                        Label(URL(string: url)?.host ?? url, systemImage: "globe")
                            .lineLimit(2)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                if let clear {
                    ToolbarItem(placement: .topBarTrailing) { Button("Clear", action: clear) }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { browser.showBookmarks = false; browser.showHistory = false }
                }
            }
        }
    }

    private var settingsSheet: some View {
        NavigationStack {
            List {
                Section("Privacy") {
                    Button("Clear history and website data", role: .destructive) {
                        browser.clearWebsiteData()
                    }
                    Text("Private tabs use a non-persistent website data store. Bookmarks remain on this device.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("About") {
                    LabeledContent("Browser", value: "BrowserOS")
                    LabeledContent("Creator", value: "ItamarOS")
                    LabeledContent("Engine", value: "Apple WebKit")
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showSettings = false } } }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
