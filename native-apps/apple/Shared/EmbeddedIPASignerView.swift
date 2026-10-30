#if os(iOS)
import Foundation
import SwiftUI
import WebKit
import UIKit

// The app remains native SwiftUI. This single, opt-in signing workspace
// loads ItamarOS's first-party zsign WebAssembly signer within the app.
// It is NOT an iOS app installer and does not sign using Apple Account login.
struct EmbeddedIPASignerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var downloadedIPA: URL?
    @State private var status = "Open the signing workspace to choose a local IPA, certificate and provisioning profile."

    private let signerURL = URL(string: "https://itamaros-web-emulator.onrender.com/signer/")!

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Label("Local IPA Signing", systemImage: "signature")
                    .font(.title2.bold())
                Text("Choose an IPA, your own Apple-issued .p12 certificate, a matching .mobileprovision and the certificate password (if needed). Signing is performed by the website's WebAssembly engine inside this app, not by Sign in with Apple.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                EmbeddedSignerWebView(url: signerURL, status: $status, downloadedIPA: $downloadedIPA)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let downloadedIPA {
                    ShareLink(item: downloadedIPA, preview: SharePreview("Signed IPA")) {
                        Label("Save or share downloaded IPA", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.updatesFrequently)

                HStack {
                    Link("Open signer in Safari", destination: signerURL)
                    Spacer()
                    Text("Signing ≠ installation")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                Text("Your Apple Account password must NEVER be entered here. The .p12 password is a separate certificate password. The signing page is downloaded over HTTPS and processes selected files locally; use only a site and certificates you trust. Valid Apple provisioning and a supported installation method are required.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("IPA Signer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct EmbeddedSignerWebView: UIViewRepresentable {
    let url: URL
    @Binding var status: String
    @Binding var downloadedIPA: URL?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Do not persist website sessions, certificate form fields or WASM caches.
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor.systemBackground
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate {
        var parent: EmbeddedSignerWebView
        private var destinations: [ObjectIdentifier: URL] = [:]

        init(parent: EmbeddedSignerWebView) { self.parent = parent }

        // Keep all interactive signing inputs on the known first-party origin.
        // Open third-party documentation only in the device's external browser.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download)
                return
            }
            guard navigationAction.targetFrame?.isMainFrame != false,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            if url.scheme == "https",
               url.host == "itamaros-web-emulator.onrender.com",
               url.path.hasPrefix("/signer/") {
                decisionHandler(.allow)
                return
            }
            if navigationAction.navigationType == .linkActivated,
               url.scheme == "https" {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let url = navigationResponse.response.url,
               url.path.lowercased().hasSuffix(".ipa") {
                decisionHandler(.download)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction,
                     didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse,
                     didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.status = "Signer loaded. Choose your files and tap Sign IPA locally."
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            parent.status = "Signer could not load. Check your connection or open it in Safari: \(error.localizedDescription)"
        }

        func download(_ download: WKDownload,
                      decideDestinationUsing response: URLResponse,
                      suggestedFilename: String,
                      completionHandler: @escaping (URL?) -> Void) {
            let name = URL(fileURLWithPath: suggestedFilename).lastPathComponent
            guard name.lowercased().hasSuffix(".ipa") else {
                parent.status = "Download rejected: only IPA files are supported."
                completionHandler(nil)
                return
            }
            let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("SignedIPADownloads", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let destination = folder.appendingPathComponent(UUID().uuidString + "-" + name)
                destinations[ObjectIdentifier(download)] = destination
                parent.status = "Downloading IPA into this app's temporary storage…"
                completionHandler(destination)
            } catch {
                parent.status = "Could not prepare IPA download: \(error.localizedDescription)"
                completionHandler(nil)
            }
        }

        func downloadDidFinish(_ download: WKDownload) {
            guard let destination = destinations.removeValue(forKey: ObjectIdentifier(download)),
                  FileManager.default.fileExists(atPath: destination.path) else {
                parent.status = "Download finished but no IPA file was found."
                return
            }
            parent.downloadedIPA = destination
            parent.status = "IPA downloaded. Use Save or Share to export it. Signing is not installation."
        }

        func download(_ download: WKDownload, didFailWithError error: Error,
                      resumeData: Data?) {
            destinations.removeValue(forKey: ObjectIdentifier(download))
            parent.status = "IPA download failed: \(error.localizedDescription)"
        }
    }
}
#endif
