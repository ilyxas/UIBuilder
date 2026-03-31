// Copyright © 2025 Apple Inc.

import MLXLMCommon
import SwiftUI
import MLX
import MLXLLM

struct LocalLLMView: View {

    let llm: LLMEvaluator
    
    init(evaluator: LLMEvaluator, chatHolder: ChatModel) {
        Memory.cacheLimit = 20 * 1024 * 1024
        self.llm = evaluator
        self.chatModel = chatHolder
    }
    
    enum DisplayStyle: String, CaseIterable, Identifiable {
        case plain, markdown
        var id: Self { self }
    }
    
    @State private var selectedDisplayStyle = DisplayStyle.markdown
    
    //@State var loader = ModelLoader()
    
    

    /// once loaded this will hold the chat session
    
    @State var error: String?

    /// prompt for the LLM (text field)
    @State var prompt = ""

    @FocusState var promptFocused

    let chatModel: ChatModel
    var body: some View {
            VStack {
                HeaderView(
                    llm: llm,
                    selectedDisplayStyle: $selectedDisplayStyle
                )

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(chatModel.messages.enumerated(), id: \.offset) { _, message in
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

                        if chatModel.isBusy {
                            HStack {
                                Button("Stop", action: { chatModel.cancel() })
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
            .padding()
            .task {
                do {
                    let model = try await llm.load()

                    if !chatModel.hasSession {
                        if chatModel.messages.isEmpty {
                            chatModel.createSession(
                                model: model,
                                genParameters: llm.generateParameters
                            )
                        } else {
                            chatModel.restoreSession(
                                model: model,
                                genParameters: llm.generateParameters
                            )
                        }
                    }
                } catch {
                    self.error = error.localizedDescription
                }
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
            chatModel.respond(prompt)
            prompt = ""
        }
    }
