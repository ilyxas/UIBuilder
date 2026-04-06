import Foundation
import MLXLMCommon

enum WorldPlannerError: Error, LocalizedError {
    case modelLoadFailed(String)
    case emptyResponse
    case decodingFailed(String)
    case timeout
    case cancelled

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let message):
            return "Model load failed: \(message)"
        case .emptyResponse:
            return "Model returned empty response"
        case .decodingFailed(let raw):
            return "Failed to decode WorldInterpretation from model response:\n\(raw)"
        case .timeout:
            return "Timed out waiting for model response"
        case .cancelled:
            return "Generation cancelled"
        }
    }
}

@MainActor
@Observable
final class WorldPlannerService {

    private let llm: LLMEvaluator
    public var chatModel: ChatModel

    var timeoutNanoseconds: UInt64 = 200_000_000_000
    var pollNanoseconds: UInt64 = 120_000_000

    init(llm: LLMEvaluator, chatModel: ChatModel) {
        self.llm = llm
        self.chatModel = chatModel
    }

    func interpret(context: WorldContext) async throws -> WorldInterpretation {
        let modelContainer: ModelContainer
        do {
            modelContainer = try await llm.load()
        } catch {
            throw WorldPlannerError.modelLoadFailed(error.localizedDescription)
        }

        let prompt = try makeUserPrompt(context: context)

        
        chatModel.dropSession()
        chatModel = ChatModel()
        chatModel.systemPrompt = makeSystemPrompt()
        if !chatModel.hasSession {
            chatModel.createSession(
                model: modelContainer,
                genParameters: llm.generateParameters
            )
        }

        let raw = try await runOneShot(prompt: prompt)

        if let decoded = tryDecode(from: raw) {
            return decoded
        }

        if let extracted = extractJSONObject(from: raw),
           let decoded = tryDecode(from: extracted) {
            return decoded
        }

        throw WorldPlannerError.decodingFailed(raw)
    }

    func resetSession() {
        chatModel.dropSession()
    }

    private func runOneShot(prompt: String) async throws -> String {
        if Task.isCancelled { throw WorldPlannerError.cancelled }

        let initialCount = chatModel.messages.count
        chatModel.respondBuffered(prompt)

        let start = DispatchTime.now().uptimeNanoseconds

        while chatModel.isBusy {
            if Task.isCancelled {
                chatModel.cancel()
                throw WorldPlannerError.cancelled
            }

            let now = DispatchTime.now().uptimeNanoseconds
            if now - start > timeoutNanoseconds {
                chatModel.cancel()
                throw WorldPlannerError.timeout
            }

            try await Task.sleep(nanoseconds: pollNanoseconds)
        }

        let newMessages = Array(chatModel.messages.dropFirst(initialCount))
        guard let assistant = newMessages.last(where: { $0.role == .assistant }) else {
            throw WorldPlannerError.emptyResponse
        }

        let content = assistant.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, content != "..." else {
            throw WorldPlannerError.emptyResponse
        }

        return content
    }

    private func makeSystemPrompt() -> String {
        """
        You choose the next move for a player on a 2D grid.

        Return ONLY valid JSON.

        Output format:
        {
          "reaction": "step_up | step_right | step_down | step_left | halt",
          "decision": "short reason"
        }

        Grid rules:
        - (0,0) is top-left
        - x increases to the right
        - y increases downward

        Movement rules:
        - step_up moves to (x, y-1)
        - step_right moves to (x+1, y)
        - step_down moves to (x, y+1)
        - step_left moves to (x-1, y)
        - halt means do not move

        Blocking rules:
        - a move is invalid if target cell is outside grid
        - a move is invalid if target cell contains obstacle

        Decision rules:
        - choose exactly one next move
        - prefer moves that reduce distance to goal
        - do not choose blocked moves
        - use halt only if no valid move exists

        Decision text:
        - Around 15-20 words
        - no storytelling
        - mention only goal/open/blocked/direction
        """
    }

    private func makeUserPrompt(context: WorldContext) throws -> String {
        let minimalState: [String: Any] = [
            "playerX": context.playerX,
            "playerY": context.playerY,
            "goalX": context.goalX,
            "goalY": context.goalY,
            "gridWidth": context.gridWidth,
            "gridHeight": context.gridHeight,
            "obstacles": context.obstacles.map { ["x": $0.x, "y": $0.y] }
        ]

        let data = try JSONSerialization.data(withJSONObject: minimalState)
        let json = String(decoding: data, as: UTF8.self)

        return "State:\n\(json)\nReturn the single best next move as JSON only."
    }

    private func tryDecode(from text: String) -> WorldInterpretation? {
        let cleaned = stripCodeFences(text)
        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WorldInterpretation.self, from: data)
    }

    private func stripCodeFences(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)

        if t.hasPrefix("```") {
            if let firstNewline = t.firstIndex(of: "\n") {
                t = String(t[t.index(after: firstNewline)...])
            }
            if let range = t.range(of: "```", options: .backwards) {
                t.removeSubrange(range.lowerBound..<t.endIndex)
            }
        }

        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractJSONObject(from s: String) -> String? {
        let t = stripCodeFences(s)
        guard let start = t.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escape = false
        var index = start

        while index < t.endIndex {
            let ch = t[index]

            if inString {
                if escape {
                    escape = false
                } else if ch == "\\" {
                    escape = true
                } else if ch == "\"" {
                    inString = false
                }
            } else {
                if ch == "\"" {
                    inString = true
                } else if ch == "{" {
                    depth += 1
                } else if ch == "}" {
                    depth -= 1
                    if depth == 0 {
                        let end = t.index(after: index)
                        return String(t[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }

            index = t.index(after: index)
        }

        return nil
    }
}
