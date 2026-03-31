////
////  ChatStore.swift
////  UIBuilder
////
////  Created by ilya on 31/03/2026.
////
//
//import MLXLLM
//import SwiftUI
//
//@MainActor
//@Observable
//class ChatStore {
//
//    var evaluator: LLMEvaluator
//
//    var chatModel: ChatModel?
//    var systemPrompt: String = "You are a helpful assistant"
//
//    init(evaluator: LLMEvaluator) {
//        self.evaluator = evaluator
//    }
//
//    /// Создать сессию если её нет
//    func ensureSession() async {
//        if chatModel != nil { return }
//
//        do {
//            let model = try await evaluator.load()
//
//            chatModel = ChatModel(
//                model: model,
//                genParameters: evaluator.generateParameters
//            )
//        } catch {
//            print("Failed to create session:", error)
//        }
//    }
//
//    /// Полный сброс сессии (новый чат / новый system prompt)
//    func resetSession() async {
//        do {
//            let model = try await evaluator.load()
//
//            chatModel = ChatModel(
//                model: model,
//                genParameters: evaluator.generateParameters,
//            )
//        } catch {
//            print("Failed to reset session:", error)
//        }
//    }
//}
