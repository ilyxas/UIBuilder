import SwiftUI
import WebKit
import Combine

final class WebViewStore: ObservableObject {
    let id: String
    let webView: WKWebView
    var urlString: String = ""
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0.0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false

    init(id: String, initialURL: String?) {
        self.id = id
        self.urlString = initialURL ?? ""

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let safariUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = safariUserAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.configuration.applicationNameForUserAgent = safariUserAgent
        webView.configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        webView.scrollView.showsHorizontalScrollIndicator = true
        webView.scrollView.showsVerticalScrollIndicator = true
        webView.isExclusiveTouch=true

        self.webView = webView

        if let initialURL,
           let url = URL(string: initialURL) {
            webView.load(URLRequest(url: url))
        }
    }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    func load(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        load(url)
    }

    func evaluateJavaScript(_ script: String, completion: ((Result<Any?, Error>) -> Void)? = nil) {
        webView.evaluateJavaScript(script) { result, error in
            if let error {
                completion?(.failure(error))
            } else {
                completion?(.success(result))
            }
        }
    }
}

final class WebViewRegistry {
    static let shared = WebViewRegistry()

    private var stores: [String: WebViewStore] = [:]

    private init() {}

    func store(for id: String, initialURL: String?) -> WebViewStore {
        if let existing = stores[id] {
            if let initialURL, existing.webView.url == nil {
                existing.load(initialURL)
            }
            return existing
        }

        let store = WebViewStore(id: id, initialURL: initialURL)
        stores[id] = store
        return store
    }

    func webView(for id: String) -> WKWebView? {
        stores[id]?.webView
    }

    func evaluate(script: String, on targetId: String, completion: ((Result<Any?, Error>) -> Void)? = nil) {
        guard let store = stores[targetId] else { return }
        store.evaluateJavaScript(script, completion: completion)
    }

    func remove(id: String) {
        stores[id] = nil
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    @ObservedObject var store: WebViewStore

    func makeUIView(context: Context) -> WKWebView {
        store.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct WebViewNodeView: View {
    let nodeId: String
    let initialURL: String?
    @State private var currentURL: URL? = URL(string: "https://www.google.com")
    

    @StateObject private var store: WebViewStore

    init(nodeId: String, initialURL: String?) {
        self.nodeId = nodeId
        self.initialURL = initialURL
        _store = StateObject(wrappedValue: WebViewRegistry.shared.store(for: nodeId, initialURL: initialURL))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    store.webView.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                
                Button {
                    store.webView.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                
                TextField("URL", text: $store.urlString)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { loadRequestedURL() }
                
                Button("Go") {
                    loadRequestedURL()
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    store.webView.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if store.isLoading {
                    ProgressView(value: store.estimatedProgress)
                        .progressViewStyle(.linear)
                        .tint(.purple)
                }
            }
                WebViewRepresentable(store: store)
                    .onDisappear {
                        WebViewRegistry.shared.remove(id: nodeId)
                    }
            
        }
    }
    
            
            private func loadRequestedURL() {
                var cleaned = store.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.lowercased().hasPrefix("http") {
                    cleaned = "https://" + cleaned
                }
                guard let url = URL(string: cleaned) else { return }
                currentURL = url
                // The load is now triggered via initialURL → makeUIView (first time)
                // or you can call store.load(url) here explicitly if you want reload on every Go press
                store.load(url)   // ← add this line if you want "Go" to force reload even on same URL
            }
}
