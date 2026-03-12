import Foundation

/// Dual-mode chat: local MLX inference or remote Nexus server SSE.
@Observable
@MainActor
final class ChatViewModel {
    enum InferenceMode: String, CaseIterable {
        case local = "On-Device (MLX)"
        case server = "Server"
    }

    var messages: [ChatMessage] = []
    var isGenerating = false
    var inferenceMode: InferenceMode = .local
    var selectedModel: AppModel = .qwen35_08b
    var lastInfoSummary: String?
    var errorMessage: String?

    let mlxService = MLXInferenceService()
    let apiService = NexusAPIService()

    // MARK: - Model Management

    var isModelLoaded: Bool {
        mlxService.modelContainer != nil
    }

    func loadSelectedModel() async {
        await mlxService.loadModel(selectedModel)
    }

    func releaseModel() {
        mlxService.releaseModel()
    }

    // MARK: - Message Sending

    func send(_ text: String, imageData: Data? = nil) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isGenerating else { return }

        let userMessage = ChatMessage(role: .user, content: text, imageData: imageData)
        messages.append(userMessage)

        let assistantMessage = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMessage)
        let assistantIndex = messages.count - 1

        isGenerating = true
        errorMessage = nil
        lastInfoSummary = nil

        switch inferenceMode {
        case .local:
            await generateLocally(assistantIndex: assistantIndex)
        case .server:
            await generateFromServer(assistantIndex: assistantIndex)
        }

        isGenerating = false
    }

    // MARK: - Local MLX Inference

    private func generateLocally(assistantIndex: Int) async {
        guard mlxService.modelContainer != nil else {
            errorMessage = "No model loaded. Load a model first."
            isGenerating = false
            return
        }

        mlxService.generate(
            messages: messages.dropLast(), // exclude the empty assistant placeholder
            onToken: { [weak self] text in
                guard let self,
                      assistantIndex < self.messages.count,
                      self.messages[assistantIndex].role == .assistant else { return }
                self.messages[assistantIndex].content += text
            },
            onComplete: { [weak self] tokensPerSec in
                guard let self else { return }
                self.lastInfoSummary = String(format: "%.1f tok/s", tokensPerSec)
            }
        )

        // Wait for generation to finish
        while mlxService.generateTask != nil {
            try? await Task.sleep(for: .milliseconds(100))
            if !isGenerating { break }
        }
    }

    // MARK: - Server SSE Inference

    private func generateFromServer(assistantIndex: Int) async {
        guard apiService.isConnected else {
            errorMessage = "Not connected to server. Go to Connect tab."
            return
        }

        let history = messages.dropLast().map { msg -> [String: String] in
            ["role": msg.role.rawValue, "content": msg.content]
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let gate = ResumeOnce(continuation)

            apiService.streamChat(
                messages: Array(history),
                model: "auto",
                method: "auto",
                onToken: { [weak self] text in
                    MainActor.assumeIsolated {
                        guard let self,
                              assistantIndex < self.messages.count,
                              self.messages[assistantIndex].role == .assistant else { return }
                        self.messages[assistantIndex].content += text
                    }
                },
                onMetrics: { [weak self] metrics in
                    MainActor.assumeIsolated {
                        self?.lastInfoSummary = String(format: "%.1f tok/s", metrics.tokensPerSec)
                    }
                    gate.resume()
                },
                onError: { [weak self] msg in
                    MainActor.assumeIsolated {
                        self?.errorMessage = msg
                    }
                    gate.resume()
                },
                onComplete: {
                    gate.resume()
                }
            )
        }
    }

    // MARK: - Actions

    func stopGeneration() {
        mlxService.cancelGeneration()
        apiService.cancelStream()
        isGenerating = false
    }

    func clearChat() {
        messages.removeAll()
        errorMessage = nil
        lastInfoSummary = nil
    }
}

/// Thread-safe one-shot continuation wrapper for use in @Sendable closures.
/// All callers are serialized on MainActor via NexusAPIService.streamChat.
private final class ResumeOnce: @unchecked Sendable {
    private var resumed = false
    private let continuation: CheckedContinuation<Void, Never>

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        guard !resumed else { return }
        resumed = true
        continuation.resume()
    }
}
