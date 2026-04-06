import SwiftUI
import UniformTypeIdentifiers


struct RootView: View {
    
    private enum Section: String, CaseIterable, Identifiable {
        case screen = "Screen"
        case localLLM = "Local LLM"
        case gameLLM = "Game LLM"
        case miniWorld = "Mini World"

        var id: Self { self }

        var icon: String {
            switch self {
            case .screen: return "iphone"
            case .localLLM: return "message"
            case .gameLLM: return "gamecontroller"
            case .miniWorld: return "globe"
            }
        }
    }

    @State private var selection: Section = .screen
    @State private var screenDocument: ScreenDocument? = nil
    @State private var isImporting = false
    @State private var importError: String? = nil
    @State private var llmEvaluator = LLMEvaluator()
    @State private var chatModel = ChatModel()
    @State private var deviceStat = DeviceStat()
    @State private var planner: WorldPlannerService = {
        // This closure will run after `llmEvaluator` has its default value.
        // We'll create a temporary evaluator to avoid referencing `self` before init.
        let evaluator = LLMEvaluator()
        let gamechatModel = ChatModel()
        return WorldPlannerService(llm: evaluator, chatModel: gamechatModel)
    }()
        
    @State private var levelPlanner: LevelPlannerService = {
        // This closure will run after `llmEvaluator` has its default value.
        // We'll create a temporary evaluator to avoid referencing `self` before init.
        let evaluator = LLMEvaluator()
        let gamechatModel = ChatModel()
        return LevelPlannerService(llm: evaluator, chatModel: gamechatModel)
    }()

    var body: some View {
        NavigationStack {
            Group {
                switch selection {
                case .screen:
                    ScreenHostView(document: $screenDocument)
                case .localLLM:
                    LocalLLMView(llm: llmEvaluator, chatModel: chatModel, deviceStat: deviceStat)
                case .gameLLM:
                    WorldPOCView(llm: llmEvaluator, planner: planner)
                case .miniWorld:
                    MiniWorldView(levelPlanner: levelPlanner)
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
                            Button {
                                selection = .gameLLM
                            } label: {
                                Label("Game LLM", systemImage: "gamecontroller")
                            }
                            Button {
                                selection = .miniWorld
                            } label: {
                                Image(systemName: "globe")
                            }
                        } label: {
                            Image(systemName: "square.grid.2x2")
                        }


                    if selection == .screen {
                        Button {
                            
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

//    private func loadBundledHomeFromRoot() {
//        do {
//            let doc = try JSONLoader.loadScreen(named: "home")
//            try DocumentValidator.validate(doc)
//            screenDocument = doc
//        } catch {
//            importError = error.localizedDescription
//        }
//    }

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

