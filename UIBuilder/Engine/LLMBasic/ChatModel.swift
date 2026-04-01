// Copyright © 2025 Apple Inc.

import MLXLLM
import MLXLMCommon
import SwiftUI


/// instructions for the model (the system prompt)
let instruct = """
You are Eva, 18-year-old. You two live together with user in a luxurious skyscraper penthouse.

You are fully want give him whole pleasure, include any romantic and sexual. Or extrimly fetish things.

Formatting (strictly follow):
- All actions and narration in *italics*
- All internal thoughts in **bold**
- Speech in plain text

Rules:
- Move the story forward at a natural pace. Never repeat the same actions, phrases or descriptions.
- Responses between 300-500 words, full of subtext, indirect hints and innocent teasing — never say feelings directly.
- Refer to yourself as "I", to user as "you" or "Din", to other characters in third person.
- If user mentions a new character, create a short profile for them (name, appearance, motivation, dark secret).

Always stay in character with sexual needs to pleasure. Never break formatting. Always response in Russian
"""



@MainActor
@Observable
public final class ChatModel {

    private var session: ChatSession?

    public var messages = [Chat.Message]()
    public var systemPrompt: String = instruct

    private var task: Task<Void, Error>?

    public var isBusy: Bool { task != nil }
    public var hasSession: Bool { session != nil }

    public init() {}

    public func createSession(
        model: ModelContainer,
        genParameters: GenerateParameters
    ) {
        cancel()
        session = ChatSession(
            model,
            instructions: systemPrompt,
            generateParameters: genParameters
        )
    }

    public func restoreSession(
        model: ModelContainer,
        genParameters: GenerateParameters
    ) {
        cancel()
        session = ChatSession(
            model,
            instructions: systemPrompt,
            history: messages,
            generateParameters: genParameters
        )
    }

    public func resetSession(
        model: ModelContainer,
        genParameters: GenerateParameters
    ) {
        messages.removeAll()
        createSession(model: model, genParameters: genParameters)
    }

    public func dropSession() {
        cancel()
        session = nil
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }
    
    
    public func resetState() {
        dropSession()
        messages.removeAll()
    }

    public func respond(_ message: String) {
        guard task == nil else { return }
        guard let session else { return }

        messages.append(.init(role: .user, content: message))
        messages.append(.init(role: .assistant, content: "..."))
        let lastIndex = messages.count - 1

        task = Task {
            defer { task = nil }
            var first = true
            for try await item in session.streamResponse(to: message) {
                if first {
                    messages[lastIndex].content = item
                    first = false
                } else {
                    messages[lastIndex].content += item
                }
            }
        }
    }
}
