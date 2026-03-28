import Foundation
import Combine
import Hub
import MLX
import MLXLLM
import MLXLMCommon

@MainActor
final class LocalLLMService: ObservableObject {
    @Published var isLoading = false
    @Published var isLoaded = false
    @Published var isGenerating = false
    @Published var modelInfo = "No model loaded"
    @Published var output = ""
    @Published var errorText: String?

    enum LoadState {
        case idle
        case loading
        case loaded(ModelContainer)
        case failed(String)
    }

    var loadState: LoadState = .idle

    @Published var downloadProgress: Double?
    @Published var totalSize: String?

    var maxTokens = 1024
    var temperature: Float = 0.6

    var modelConfiguration = LLMRegistry.llama3_8B_4bit

    private var generationTask: Task<String, Error>?

    func loadModel() async throws {
        guard !isLoading else { return }

        if case .loaded = loadState {
            isLoaded = true
            return
        }

        isLoading = true
        errorText = nil
        modelInfo = "Preparing..."
        downloadProgress = 0
        totalSize = nil

        Memory.cacheLimit = 20 * 1024 * 1024

        let hub = HubApi(
            downloadBase: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        )

        do {
            loadState = .loading

            let modelDirectory = try await downloadModel(
                hub: hub,
                configuration: modelConfiguration
            ) { [weak self] progress in
                guard let self else { return }
                Task { @MainActor in
                    self.downloadProgress = progress.fractionCompleted
                    self.modelInfo = "Downloading \(self.shortModelName) (\(Int(progress.fractionCompleted * 100))%)"

                    if progress.totalUnitCount > 0 && progress.totalUnitCount < 100 {
                        self.totalSize = "File \(progress.completedUnitCount + 1) of \(progress.totalUnitCount)"
                    } else if progress.totalUnitCount > 0 {
                        self.totalSize = "\(self.formatBytes(progress.completedUnitCount)) of \(self.formatBytes(progress.totalUnitCount))"
                    } else {
                        self.totalSize = nil
                    }
                }
            }

            let contents = try FileManager.default.contentsOfDirectory(atPath: modelDirectory.path)
            guard contents.contains(where: { $0.hasSuffix(".safetensors") }) else {
                throw NSError(
                    domain: "LocalLLMService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Download finished but model weights were not found."]
                )
            }

            modelInfo = "Loading \(shortModelName)..."
            downloadProgress = nil
            totalSize = nil

            let container = try await LLMModelFactory.shared.loadContainer(
                hub: hub,
                configuration: modelConfiguration
            ) { _ in }

            let numParams = await container.perform { $0.model.numParameters() }

            loadState = .loaded(container)
            isLoaded = true
            modelInfo = "\(shortModelName) • \(formattedParams(numParams))"
            isLoading = false
        } catch {
            loadState = .failed(error.localizedDescription)
            isLoaded = false
            errorText = error.localizedDescription
            modelInfo = "Failed to load model"
            downloadProgress = nil
            totalSize = nil
            isLoading = false
            throw error
        }
    }

    func unloadModel() {
        generationTask?.cancel()
        generationTask = nil
        loadState = .idle
        isLoading = false
        isGenerating = false
        isLoaded = false
        downloadProgress = nil
        totalSize = nil
        output = ""
        modelInfo = "No model loaded"
        errorText = nil
    }

    func send(prompt: String, systemPrompt: String = "You are a concise assistant.") async throws -> String {
        guard !isGenerating else {
            throw NSError(
                domain: "LocalLLMService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Generation is already in progress."]
            )
        }

        guard case .loaded(let container) = loadState else {
            throw NSError(
                domain: "LocalLLMService",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Model is not loaded."]
            )
        }

        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(
                domain: "LocalLLMService",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Prompt is empty."]
            )
        }

        isGenerating = true
        errorText = nil
        output = ""

        generationTask = Task<String, Error> { [weak self] in
            guard let self else {
                throw NSError(
                    domain: "LocalLLMService",
                    code: -5,
                    userInfo: [NSLocalizedDescriptionKey: "Service was released."]
                )
            }

            do {
                MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

                let userInput = UserInput(
                    chat: [
                        .system(systemPrompt),
                        .user(trimmed)
                    ]
                )

                let parameters = GenerateParameters(
                    maxTokens: maxTokens,
                    temperature: temperature
                )

                let lmInput = try await container.prepare(input: userInput)
                let stream = try await container.generate(input: lmInput, parameters: parameters)

                var text = ""
                var iterator = stream.makeAsyncIterator()

                while let next = await iterator.next() {
                    try Task.checkCancellation()

                    if let chunk = next.chunk, !chunk.isEmpty {
                        text += chunk
                        await MainActor.run {
                            self.output = text
                        }
                    }
                }

                await MainActor.run {
                    self.isGenerating = false
                }

                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch is CancellationError {
                await MainActor.run {
                    self.isGenerating = false
                    self.errorText = "Generation cancelled."
                }
                throw NSError(
                    domain: "LocalLLMService",
                    code: -6,
                    userInfo: [NSLocalizedDescriptionKey: "Generation cancelled."]
                )
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    self.errorText = error.localizedDescription
                }
                throw error
            }
        }

        let result = try await generationTask!.value
        generationTask = nil
        return result
    }

    func generateJavaScript(from task: String, pageContext: String? = nil) async throws -> String {
        let contextBlock: String
        if let pageContext, !pageContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contextBlock = """

            Page context:
            \(pageContext)
            """
        } else {
            contextBlock = ""
        }

        let prompt = """
        Task:
        \(task)
        \(contextBlock)

        Return only plain JavaScript for execution in a browser page.
        Do not wrap in markdown.
        Do not explain.
        Do not include code fences.
        """

        return try await send(
            prompt: prompt,
            systemPrompt: """
            You generate concise browser JavaScript.
            Return only executable JavaScript.
            No markdown.
            No comments unless they are required inside the script itself.
            """
        )
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }

    private var shortModelName: String {
        modelConfiguration.name.components(separatedBy: "/").last ?? modelConfiguration.name
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formattedParams(_ parameters: Int) -> String {
        let millions = parameters / (1024 * 1024)
        if millions >= 1000 {
            return String(format: "%.1fB params", Double(millions) / 1000.0)
        } else {
            return "\(millions)M params"
        }
    }
}
