//
//  ScreenHostView.swift
//  UIBuilder
//
//  Created by ilya on 26/03/2026.
//

import SwiftUI
import UniformTypeIdentifiers


struct ScreenHostView: View {
    init(document: Binding<ScreenDocument?> = .constant(nil)) {
        self._document = document
    }

    @Binding var document: ScreenDocument?
    @State private var toastMessage: String?
    @State private var importError: String?
    @State private var isImporting = false

    @State private var stateStore = UIStateStore()
    @State private var navigationStore = NavigationStore()
    @State private var controlsExpanded = false
    @State private var didAttemptInitialLoad = false

    var body: some View {
        VStack(spacing: 0) {
            if let document {
                let executor = UIActionExecutor(state: stateStore, navigation: navigationStore)

                UIRenderer(
                    node: document.root,
                    document: document,
                    state: stateStore,
                    executor: configured(executor)
                )
            } else {
                VStack(spacing: 16) {
                    Text("No screen loaded")
                    Text("Use the controls above to load a screen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding()
            }
        }
        .task {
            guard !didAttemptInitialLoad else { return }
            didAttemptInitialLoad = true
            if document == nil {
                await loadBundledHome()
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

    @MainActor private func loadBundledHome() async {
        do {
            let doc = try JSONLoader.loadScreen(named: "home")
            try DocumentValidator.validate(doc)
            applyDocument(doc)
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

            Task { @MainActor in
                applyDocument(doc)
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    @MainActor
    private func applyDocument(_ doc: ScreenDocument) {
        document = doc
        stateStore = UIStateStore(initial: doc.state?.vars ?? [:])
        navigationStore = NavigationStore()
    }

    private func configured(_ executor: UIActionExecutor) -> UIActionExecutor {
        executor.onToast = { message in
            toastMessage = message
        }
        executor.onAIRequest = { id, input in
            print("AI request:", id, input)
        }
        return executor
    }
}

