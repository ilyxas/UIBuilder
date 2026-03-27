import Foundation
import Combine
import Hub
import MLX
import MLXLLM
import MLXLMCommon

@MainActor
final class LocalLLMViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var generatedScript: String = ""
    @Published var selectedModelName: String = "llama3_8B_4bit"
    @Published var errorText: String?

    @Published private(set) var isLoading = false
    @Published private(set) var isModelLoaded = false
    @Published private(set) var isGenerating = false
    @Published private(set) var modelInfo: String = "No model loaded"
    @Published private(set) var liveOutput: String = ""

    let service = LocalLLMService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        bindService()
        syncFromService()
    }

    func loadModel() async {
        clearError()
        applySelectedModelIfNeeded()

        do {
            try await service.loadModel()
            syncFromService()
        } catch {
            errorText = error.localizedDescription
            syncFromService()
        }
    }

    func unloadModel() {
        clearError()
        service.unloadModel()
        syncFromService()
    }

    func warmup() async {
        clearError()

        do {
            _ = try await service.send(
                prompt: "Reply with exactly: ready",
                systemPrompt: "You are a concise assistant."
            )
            syncFromService()
        } catch {
            errorText = error.localizedDescription
            syncFromService()
        }
    }

    func sendMessage() async {
        clearError()

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard isModelLoaded else {
            errorText = "Model is not loaded."
            return
        }

        messages.append(ChatMessage(role: .user, text: trimmed))
        inputText = ""

        do {
            let reply = try await service.send(
                prompt: buildChatPrompt(from: messages),
                systemPrompt: "You are a helpful concise assistant."
            )

            messages.append(ChatMessage(role: .assistant, text: reply))
            syncFromService()
        } catch {
            errorText = error.localizedDescription
            syncFromService()
        }
    }

    func generateScript(pageContext: String? = nil) async {
        clearError()

        guard isModelLoaded else {
            errorText = "Model is not loaded."
            return
        }

        let taskPrompt: String
        if let lastUserMessage = messages.last(where: { $0.role == .user })?.text,
           !lastUserMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            taskPrompt = lastUserMessage
        } else {
            taskPrompt = "Generate JavaScript for the current page."
        }

        do {
            let script = try await service.generateJavaScript(
                from: taskPrompt,
                pageContext: pageContext
            )
            generatedScript = script.trimmingCharacters(in: .whitespacesAndNewlines)
            syncFromService()
        } catch {
            errorText = error.localizedDescription
            syncFromService()
        }
    }

    func clearChat() {
        messages.removeAll()
        generatedScript = ""
        liveOutput = ""
        clearError()
    }

    func appendSystemMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(role: .system, text: trimmed))
    }

    func sendScriptToWebView(webViewId: String) async {
        clearError()

        let trimmedId = webViewId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedScript = generatedScript.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedId.isEmpty else {
            errorText = "WebView id is empty."
            return
        }

        guard !trimmedScript.isEmpty else {
            errorText = "No generated script to send."
            return
        }

        do {
            _ = try await WebViewRegistry.shared.evaluateAsync(
                script: trimmedScript,
                on: trimmedId
            )
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func buildChatPrompt(from messages: [ChatMessage]) -> String {
        let recent = messages.suffix(8)

        return recent
            .map { message in
                switch message.role {
                case .system:
                    return "System: \(message.text)"
                case .user:
                    return "User: \(message.text)"
                case .assistant:
                    return "Assistant: \(message.text)"
                }
            }
            .joined(separator: "\n\n")
    }

    private func applySelectedModelIfNeeded() {
        switch selectedModelName.lowercased() {
        case "phi4bit", "phi":
            service.modelConfiguration = LLMRegistry.phi4bit
        case "qwen205b4bit", "qwen2", "qwen2.5", "qwen2.5-coder", "qwen205":
            service.modelConfiguration = LLMRegistry.qwen205b4bit
        case "qwen3_8b_4bit", "qwen3":
            service.modelConfiguration = LLMRegistry.qwen3_8b_4bit
        default:
            service.modelConfiguration = LLMRegistry.qwen205b4bit
        }
    }

    private func bindService() {
        service.$isLoading
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.isLoading = $0 }
            .store(in: &cancellables)

        service.$isLoaded
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.isModelLoaded = $0 }
            .store(in: &cancellables)

        service.$isGenerating
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.isGenerating = $0 }
            .store(in: &cancellables)

        service.$modelInfo
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.modelInfo = $0 }
            .store(in: &cancellables)

        service.$output
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.liveOutput = $0 }
            .store(in: &cancellables)

        service.$errorText
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                guard let value, !value.isEmpty else { return }
                self?.errorText = value
            }
            .store(in: &cancellables)
    }

    private func syncFromService() {
        isLoading = service.isLoading
        isModelLoaded = service.isLoaded
        isGenerating = service.isGenerating
        modelInfo = service.modelInfo
        liveOutput = service.output
        if let serviceError = service.errorText, !serviceError.isEmpty {
            errorText = serviceError
        }
    }

    private func clearError() {
        errorText = nil
    }
}
