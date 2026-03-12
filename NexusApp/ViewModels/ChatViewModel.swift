import Foundation
import SwiftUI

@Observable
@MainActor
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var isGenerating = false
    var tokensPerSec: Double = 0
    var inputText = ""

    private var generationTask: Task<Void, Never>?
    private var tokenCount = 0
    private var generationStart: Date?

    init() {
        messages.append(ChatMessage(role: .system, content: "You are a helpful AI assistant."))
    }

    // MARK: - Send

    func send(appState: AppState) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))
        messages.append(ChatMessage(role: .assistant, content: ""))

        isGenerating = true
        tokenCount = 0
        tokensPerSec = 0
        generationStart = Date()

        generationTask = Task { [weak self] in
            guard let self else { return }

            do {
                switch appState.inferenceMode {
                case .server:
                    try await self.streamCloud(appState: appState)
                case .onDevice:
                    try await self.streamLocal(appState: appState)
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.appendToLastAssistant("\n\n[Error: \(error.localizedDescription)]")
                    }
                }
            }

            await MainActor.run {
                self.isGenerating = false
                self.reportMetrics(appState: appState)
            }
        }
    }

    func stop(appState: AppState) {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        appState.llamaEngine.cancelGeneration()
    }

    // MARK: - Cloud Streaming

    private func streamCloud(appState: AppState) async throws {
        guard let modelFile = appState.selectedModelFile else {
            throw NexusError.inferenceError("No model selected")
        }

        let apiMessages = messages
            .filter { $0.role != .system || $0 == messages.first }
            .dropLast() // drop the empty assistant message
            .map { $0.apiDict }

        let token = await appState.currentAuthToken()

        let stream = appState.apiClient.streamCloudInference(
            serverUrl: appState.serverUrl,
            modelFile: modelFile,
            method: appState.selectedModelMethod ?? "GGUF",
            messages: Array(apiMessages),
            authToken: token
        )

        for try await token in stream {
            if Task.isCancelled { break }
            await MainActor.run {
                self.appendToLastAssistant(token)
                self.tokenCount += 1
                self.updateTokensPerSec()
            }
        }
    }

    // MARK: - Local Streaming

    private func streamLocal(appState: AppState) async throws {
        guard appState.llamaEngine.isModelLoaded else {
            throw NexusError.modelNotLoaded
        }

        let chatMessages = messages.dropLast() // drop empty assistant message
        let stream = appState.llamaEngine.generate(messages: Array(chatMessages))

        for try await token in stream {
            if Task.isCancelled { break }
            await MainActor.run {
                self.appendToLastAssistant(token)
                self.tokenCount += 1
                self.updateTokensPerSec()
            }
        }
    }

    // MARK: - Helpers

    private func appendToLastAssistant(_ text: String) {
        guard let lastIndex = messages.indices.last,
              messages[lastIndex].role == .assistant else { return }
        messages[lastIndex].content += text
    }

    private func updateTokensPerSec() {
        guard let start = generationStart else { return }
        let elapsed = Date().timeIntervalSince(start)
        if elapsed > 0 {
            tokensPerSec = Double(tokenCount) / elapsed
        }
    }

    private func reportMetrics(appState: AppState) {
        guard let start = generationStart, let deviceId = appState.deviceId else { return }
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0, tokenCount > 0 else { return }

        let tps = Double(tokenCount) / elapsed
        appState.metricsReporter.recordInference(
            tokensPerSec: tps,
            tokenCount: tokenCount,
            elapsed: elapsed,
            activeModel: appState.selectedModelName ?? "",
            inferenceMode: appState.inferenceMode,
            serverUrl: appState.serverUrl,
            deviceId: deviceId
        )
    }

    func clearChat() {
        messages = [ChatMessage(role: .system, content: "You are a helpful AI assistant.")]
        tokenCount = 0
        tokensPerSec = 0
    }
}
