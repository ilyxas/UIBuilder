import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case screen = "Screen"
        case localLLM = "Local LLM"

        var id: Self { self }

        var icon: String {
            switch self {
            case .screen: return "iphone"
            case .localLLM: return "message"
            }
        }
    }

    @State private var selection: Section = .screen
    @State private var screenDocument: ScreenDocument? = nil
    @State private var isImporting = false
    @State private var importError: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                switch selection {
                case .screen:
                    ScreenHostView(document: $screenDocument)
                case .localLLM:
                    LocalLLMView()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Menu {
                        Button {
                            selection = .screen
                        } label: {
                            Label("Screen", systemImage: "iphone")
                        }
                        Button {
                            selection = .localLLM
                        } label: {
                            Label("Local LLM", systemImage: "message")
                        }
                    } label: {
                        Image(systemName: "square.grid.2x2")
                    }

                    if selection == .screen {
                        Button {
                            loadBundledHomeFromRoot()
                        } label: {
                            Image(systemName: "house")
                        }
                        .accessibilityLabel("Load bundled home")

                        Button {
                            isImporting = true
                        } label: {
                            Image(systemName: "arrow.up.doc")
                        }
                        .accessibilityLabel("Upload Screen JSON")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Import Error", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) {
                importError = nil
            }
        } message: {
            Text(importError ?? "")
        }
    }

    private func loadBundledHomeFromRoot() {
        do {
            let doc = try JSONLoader.loadScreen(named: "home")
            try DocumentValidator.validate(doc)
            screenDocument = doc
        } catch {
            importError = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }

            let granted = url.startAccessingSecurityScopedResource()
            defer {
                if granted { url.stopAccessingSecurityScopedResource() }
            }

            let data = try Data(contentsOf: url)
            let doc = try JSONDecoder().decode(ScreenDocument.self, from: data)
            try DocumentValidator.validate(doc)
            screenDocument = doc
        } catch {
            importError = error.localizedDescription
        }
    }
}

#Preview {
    RootView()
}
