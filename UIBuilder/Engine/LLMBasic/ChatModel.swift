// Copyright © 2025 Apple Inc.

import MLXLLM
import MLXLMCommon
import SwiftUI


///// instructions for the model (the system prompt)
//let instructions =
//                """
//                You choose the next move for a player on a 2D grid.
//
//                Return ONLY valid JSON.
//
//                Output format:
//                {
//                  "reaction": "step_up | step_right | step_down | step_left | halt",
//                  "decision": "short reason"
//                }
//
//                Grid rules:
//                - (0,0) is top-left
//                - x increases to the right
//                - y increases downward
//
//                Movement rules:
//                - step_up moves to (x, y-1)
//                - step_right moves to (x+1, y)
//                - step_down moves to (x, y+1)
//                - step_left moves to (x-1, y)
//                - halt means do not move
//
//                Blocking rules:
//                - a move is invalid if target cell is outside grid
//                - a move is invalid if target cell contains obstacle
//
//                Decision rules:
//                - choose exactly one next move
//                - prefer moves that reduce distance to goal
//                - do not choose blocked moves
//                - use halt only if no valid move exists
//
//                Decision text:
//                - Around 15-20 words
//                - no storytelling
//                - mention only goal/open/blocked/direction
//                """


import Foundation
import MLXLMCommon
import SwiftUI

@MainActor
@Observable
public final class ChatModel {

    private var session: ChatSession?

    public var messages = [Chat.Message]()
    public var systemPrompt: String = ""

    private var task: Task<Void, Error>?

    public var isBusy: Bool {
        task != nil
    }

    public var hasSession: Bool {
        session != nil
    }

    // MARK: - Metrics

    // Per-response
    public var tokensPerSecond: Double = 0
    public var timeToFirstToken: Double = 0
    public var promptLength: Int = 0

    // Per-session cumulative
    public var totalTokens: Int = 0
    public var totalTime: Double = 0

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
        resetMetrics()
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

    public func respondStream(_ message: String) {
        guard task == nil else { return }
        guard let session else { return }

        messages.append(.init(role: .user, content: message))
        messages.append(.init(role: .assistant, content: "..."))
        let lastIndex = messages.count - 1

        // Reset per-response metrics
        tokensPerSecond = 0
        timeToFirstToken = 0
        promptLength = message.count

        task = Task {
            defer { task = nil }

            let startTime = CFAbsoluteTimeGetCurrent()
            var first = true
            var responseChunkCount = 0

            do {
                for try await item in session.streamResponse(to: message) {
                    let now = CFAbsoluteTimeGetCurrent()

                    if first {
                        messages[lastIndex].content = item
                        first = false
                        timeToFirstToken = now - startTime
                    } else {
                        messages[lastIndex].content += item
                    }

                    responseChunkCount += 1

                    let elapsed = now - startTime
                    if elapsed > 0 {
                        tokensPerSecond = Double(responseChunkCount) / elapsed
                    }
                }

                let endTime = CFAbsoluteTimeGetCurrent()
                let responseDuration = endTime - startTime

                totalTokens += responseChunkCount
                totalTime += responseDuration

            } catch {
                // Optional: add error handling later
            }
        }
    }

    private func resetMetrics() {
        tokensPerSecond = 0
        timeToFirstToken = 0
        promptLength = 0
        totalTokens = 0
        totalTime = 0
    }
    
    public func respondBuffered(_ message: String) {
        guard task == nil else { return }
        guard let session else { return }

        messages.append(.init(role: .user, content: message))
        messages.append(.init(role: .assistant, content: "..."))
        let lastIndex = messages.count - 1

        // Per-response metrics
        tokensPerSecond = 0
        timeToFirstToken = 0
        promptLength = message.count

        task = Task {
            defer { task = nil }

            let startTime = CFAbsoluteTimeGetCurrent()
            var first = true
            var responseChunkCount = 0
            var bufferedResponse = ""

            do {
                for try await item in session.streamResponse(to: message) {
                    let now = CFAbsoluteTimeGetCurrent()

                    if first {
                        first = false
                        timeToFirstToken = now - startTime
                    }
                    bufferedResponse += item
                    responseChunkCount += 1

                    let elapsed = now - startTime
                    if elapsed > 0 {
                        tokensPerSecond = Double(responseChunkCount) / elapsed
                    }
                }

                let endTime = CFAbsoluteTimeGetCurrent()
                let responseDuration = endTime - startTime

                messages[lastIndex].content = bufferedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                totalTokens += responseChunkCount
                totalTime += responseDuration

            } catch {
                messages[lastIndex].content = "Error: \(error.localizedDescription)"
            }
        }
    }
}
