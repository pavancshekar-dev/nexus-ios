import Foundation
import UIKit
import MLX
import MLXLMCommon
import MLXLLM
import MLXVLM

/// Manages local MLX model loading and text generation.
@Observable
@MainActor
final class MLXInferenceService {
    var modelContainer: ModelContainer?
    var isLoading = false
    var loadProgress: Double = 0
    var errorMessage: String?

    private static let maxTokens = 1024
    private static let gpuCacheLimit = 512 * 1024 * 1024 // 512 MB

    private(set) var generateTask: Task<Void, Never>?

    // MARK: - Model Loading

    func loadModel(_ model: AppModel) async {
        isLoading = true
        loadProgress = 0
        errorMessage = nil

        // Release previous model
        releaseModel()

        MLX.GPU.set(cacheLimit: Self.gpuCacheLimit)

        do {
            let container = try await loadModelContainer(
                id: model.huggingFaceID
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.loadProgress = progress.fractionCompleted
                }
            }
            modelContainer = container
        } catch {
            errorMessage = "Failed to load model: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func releaseModel() {
        generateTask?.cancel()
        generateTask = nil
        modelContainer = nil
        MLX.GPU.set(cacheLimit: 0)
        MLX.GPU.clearCache()
    }

    // MARK: - Text Generation

    func generate(
        messages: [ChatMessage],
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (Double) -> Void
    ) {
        guard let container = modelContainer else {
            errorMessage = "No model loaded"
            return
        }

        generateTask?.cancel()
        generateTask = Task {
            do {
                var chatMessages: [Chat.Message] = [
                    .system("You are a helpful assistant.")
                ]

                for msg in messages {
                    switch msg.role {
                    case .user:
                        if let img = msg.image,
                           let ciImage = CIImage(image: img) {
                            chatMessages.append(.user(msg.content, images: [.ciImage(ciImage)]))
                        } else {
                            chatMessages.append(.user(msg.content))
                        }
                    case .assistant:
                        chatMessages.append(.assistant(msg.content))
                    case .system:
                        break
                    }
                }

                let input = UserInput(
                    chat: chatMessages,
                    processing: .init(resize: CGSize(width: 512, height: 512)),
                    additionalContext: ["enable_thinking": false]
                )

                let params = GenerateParameters(
                    maxTokens: Self.maxTokens,
                    temperature: 0.7
                )

                let lmInput = try await container.prepare(input: input)
                let stream = try await container.generate(input: lmInput, parameters: params)

                var tokensPerSec: Double = 0
                for try await generation in stream {
                    if Task.isCancelled { break }
                    switch generation {
                    case .chunk(let text):
                        await MainActor.run { onToken(text) }
                    case .info(let info):
                        tokensPerSec = info.tokensPerSecond
                    default:
                        break
                    }
                }

                await MainActor.run { onComplete(tokensPerSec) }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.errorMessage = "Generation error: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func cancelGeneration() {
        generateTask?.cancel()
        generateTask = nil
    }
}
