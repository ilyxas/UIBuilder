import SwiftUI
import UniformTypeIdentifiers


struct RootView: View {
    
    private enum Section: String, CaseIterable, Identifiable {
        case soccerPenalty = "Penalty"
        case localLLM = "Local LLM"
        

        var id: Self { self }

        var icon: String {
            switch self {
            case .soccerPenalty: return "soccerball"
            case .localLLM: return "message"
            }
        }
    }

    @State private var selection: Section = .soccerPenalty
    @State private var isImporting = false
    @State private var importError: String? = nil
    @State private var llmEvaluator = LLMEvaluator()
    @State private var chatModel = ChatModel()
    @State private var deviceStat = DeviceStat()
        
    @State private var levelPlanner: LevelPlannerService = {
        // This closure will run after `llmEvaluator` has its default value.
        // We'll create a temporary evaluator to avoid referencing `self` before init.
        let evaluator = LLMEvaluator()
        let gamechatModel = ChatModel()
        return LevelPlannerService(llm: evaluator, chatModel: gamechatModel)
    }()

    @State private var penaltyPlanner: SoccerPenaltyPlannerService = {
        let evaluator = LLMEvaluator()
        let chatModel = ChatModel()
        return SoccerPenaltyPlannerService(llm: evaluator, chatModel: chatModel)
    }()

    var body: some View {
        NavigationStack {
            Group {
                switch selection {
                case .localLLM:
                    LocalLLMView(llm: llmEvaluator, chatModel: chatModel, deviceStat: deviceStat)
                case .soccerPenalty:
                    SoccerPenaltyView(planner: penaltyPlanner)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Menu {
                            Button {
                                selection = .localLLM
                            } label: {
                                Label("Local LLM", systemImage: "message")
                            }
                            Button {
                                selection = .soccerPenalty
                            } label: {
                                Label("Penalty", systemImage: "soccerball")
                            }
                        } label: {
                            Image(systemName: "square.grid.2x2")
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
        } catch {
            importError = error.localizedDescription
        }
    }
}

