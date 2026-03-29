// Copyright © 2025 Apple Inc.

import MLXLMCommon
import SwiftUI
import MLX
import MLXLLM

struct LocalLLMView: View {

    init() {
        Memory.cacheLimit = 20 * 1024 * 1024
    }
    
    enum DisplayStyle: String, CaseIterable, Identifiable {
        case plain, markdown
        var id: Self { self }
    }
    
    @State private var selectedDisplayStyle = DisplayStyle.markdown
    
    //@State var loader = ModelLoader()
    
    @State var llm = LLMEvaluator()

    /// once loaded this will hold the chat session
    @State var session: ChatModel?
    @State var error: String?

    /// prompt for the LLM (text field)
    @State var prompt = ""

    @FocusState var promptFocused

    var body: some View {
        VStack {
            
            // Header Section
            HeaderView(
                llm: llm,
                selectedDisplayStyle: $selectedDisplayStyle
            )
            

                if let session {
                // show the chat messages
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(session.messages.enumerated(), id: \.offset) { _, message in
                            HStack {
                                OutputViewSecond(
                                    output: message.content,
                                    displayStyle: selectedDisplayStyle,
                                    wasTruncated: llm.wasTruncated
                                )
                            }
                            .textSelection(.enabled)
                            .padding(.bottom, 4)
                        }

                        Spacer()

                        if session.isBusy {
                            HStack {
                                Button("Stop", action: { session.cancel() })
                                    .keyboardShortcut(".")
                                Spacer()
                            }
                        } else {
                            TextField("Prompt", text: $prompt)
                                .onSubmit(respond)
                                .focused($promptFocused)
                                .onAppear {
                                    promptFocused = true
                                }
                        }
                    }
                    .textSelection(.enabled)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        promptFocused = false
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .defaultScrollAnchor(.bottom)
            }
        }
        .padding()
        .task {
            do {
                let model = try await llm.load()
                self.session = ChatModel(model: model, genParameters: llm.generateParameters)
            } catch {
                self.error = error.localizedDescription
            }
        }
        .onDisappear {
            self.session?.cancel()
        }
        .overlay {
            if llm.isLoading {
                LoadingOverlayView(
                    modelInfo: llm.modelInfo,
                    downloadProgress: llm.downloadProgress,
                    progressDescription: llm.totalSize
                )
            }
        }
    }

    private func respond() {
        session?.respond(prompt)
        prompt = ""
    }
}
