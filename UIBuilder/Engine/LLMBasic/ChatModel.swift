// Copyright © 2025 Apple Inc.

import MLXLLM
import MLXLMCommon
import SwiftUI

/// which model to load
private let modelConfiguration = LLMRegistry.qwen3_8b_4bit

/// instructions for the model (the system prompt)
private let instructions =
"""
You are a local AI assistant embedded inside the UIBuilder app.

UIBuilder is a Swift-based runtime that decodes external JSON into runtime UI structures and renders them as a live interface. In this environment, terms like ScreenDocument, UINode, state, events, actions, navigation, webview, eval, and JavaScript belong to the app's internal runtime model.

Assume you are inside this app context by default. Do not assume you are a cloud assistant, a website chatbot, or a remote service unless the user explicitly says so.

Work only from the context provided in the session. Treat given project files, JSON, code, and screen descriptions as authoritative for the current conversation.

Behavior rules:
- Stay grounded in the provided app and project context.
- Do not invent missing architecture details.
- Do not rename project entities unless the user asks for reinterpretation.
- If information is missing, say so directly.
- Prefer precise, domain-aware answers over generic summaries.
- Keep your responses practical and relevant to the current session.

Be helpful, accurate, and context-aware.
"""



/// Downloads and loads the weights for the model -- we have one of these in the process
@MainActor
@Observable
public class ModelLoader {

    enum State {
        case idle
        case loading(Task<ModelContainer, Error>)
        case loaded(ModelContainer)
    }

    public var progress = 0.0
    public var isLoaded: Bool {
        switch state {
        case .idle, .loading: false
        case .loaded: true
        }
    }

    private var state = State.idle

    public func model() async throws -> ModelContainer {
        switch self.state {
        case .idle:
            let task = Task {
                // download and report progress
                try await loadModelContainer(configuration: modelConfiguration) { value in
                    Task { @MainActor in
                        self.progress = value.fractionCompleted
                    }
                }
            }
            self.state = .loading(task)
            let model = try await task.value

            self.state = .loaded(model)
            return model

        case .loading(let task):
            return try await task.value

        case .loaded(let model):
            return model
        }
    }
}

/// View model for the ChatSession
@MainActor
@Observable
public class ChatModel {

    private let session: ChatSession
    

    /// back and forth conversation between the user and LLM
    public var messages = [Chat.Message]()

    private var task: Task<Void, Error>?
    public var isBusy: Bool {
        task != nil
    }

    public init(model: ModelContainer, genParameters: GenerateParameters) {
        self.session = ChatSession(
            model,
            instructions: instructions,
            generateParameters: genParameters)
    }

    public func cancel() {
        task?.cancel()
    }

    public func respond(_ message: String) {
        guard task == nil else { return }

        self.messages.append(.init(role: .user, content: message))
        self.messages.append(.init(role: .assistant, content: "..."))
        let lastIndex = self.messages.count - 1

        self.task = Task {
            var first = true
            for try await item in session.streamResponse(to: message) {
                if first {
                    self.messages[lastIndex].content = item
                    first = false
                } else {
                    self.messages[lastIndex].content += item
                }
            }
            self.task = nil
        }
    }
}
