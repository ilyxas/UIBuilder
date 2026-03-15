import SwiftUI

struct RootView: View {
    @State private var document: ScreenDocument?
    @State private var toastMessage: String?
    @State private var alertTitle: String?
    @State private var alertMessage: String?

    @State private var stateStore = UIStateStore()
    @State private var navigationStore = NavigationStore()

    var body: some View {
        Group {
            if let document {
                let executor = UIActionExecutor(state: stateStore, navigation: navigationStore)

                UIRenderer(
                    node: document.root,
                    document: document,
                    state: stateStore,
                    executor: configured(executor)
                )
                .padding()
            } else {
                ProgressView()
                    .task {
                        await load()
                    }
            }
        }
        .alert("Toast", isPresented: Binding(
            get: { toastMessage != nil },
            set: { if !$0 { toastMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(toastMessage ?? "")
        }
        .alert(alertTitle ?? "", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertTitle = nil; alertMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    @MainActor
    private func load() async {
        do {
            let doc = try JSONLoader.loadScreen(named: "home")

							try DocumentValidator.validate(doc)

							document = doc
							stateStore = UIStateStore(initial: doc.state?.vars ?? [:])
        } catch {
            print("Load error:", error)
        }
    }

    private func configured(_ executor: UIActionExecutor) -> UIActionExecutor {
        executor.onToast = { message in
            toastMessage = message
        }
        executor.onAlert = { title, message in
            alertTitle = title
            alertMessage = message
        }
        executor.onAIRequest = { id, input in
            print("AI request:", id, input)
        }
        return executor
    }
}