import Foundation
import Observation
import LlamaSwift

@Observable
final class LlamaEngine: @unchecked Sendable {
    private(set) var isModelLoaded = false
    private(set) var isGenerating = false
    private(set) var loadedModelName: String?

    private var model: OpaquePointer?      // llama_model *
    private var context: OpaquePointer?    // llama_context *
    private var sampler: UnsafeMutablePointer<llama_sampler>?

    private let queue = DispatchQueue(label: "com.qpiai.nexus.llama", qos: .userInitiated)
    private var cancelled = false

    private let contextSize: Int32 = 8192
    private let batchSize: Int32 = 512
    private let temperature: Float = 0.3

    deinit {
        unloadModel()
        llama_backend_free()
    }

    init() {
        llama_backend_init()
    }

    // MARK: - Model Management

    func loadModel(path: String, name: String) throws {
        unloadModel()

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 99 // Use Metal if available

        guard let m = llama_model_load_from_file(path, modelParams) else {
            throw NexusError.inferenceError("Failed to load model from: \(path)")
        }
        model = m

        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = UInt32(contextSize)
        ctxParams.n_batch = UInt32(batchSize)
        ctxParams.n_threads = Int32(min(max(ProcessInfo.processInfo.processorCount - 2, 2), 4))

        guard let c = llama_init_from_model(m, ctxParams) else {
            llama_model_free(m)
            model = nil
            throw NexusError.inferenceError("Failed to create context")
        }
        context = c

        // Create sampler chain
        let sparams = llama_sampler_chain_default_params()
        guard let chain = llama_sampler_chain_init(sparams) else {
            llama_free(c)
            llama_model_free(m)
            context = nil
            model = nil
            throw NexusError.inferenceError("Failed to create sampler chain")
        }
        llama_sampler_chain_add(chain, llama_sampler_init_temp(temperature))
        llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))
        sampler = chain

        isModelLoaded = true
        loadedModelName = name
    }

    func unloadModel() {
        cancelled = true
        queue.sync {
            if let s = sampler { llama_sampler_free(s); sampler = nil }
            if let c = context { llama_free(c); context = nil }
            if let m = model { llama_model_free(m); model = nil }
        }
        isModelLoaded = false
        loadedModelName = nil
        cancelled = false
    }

    // MARK: - Generation

    func generate(
        messages: [ChatMessage],
        maxTokens: Int = 512
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard let model = self.model,
                  let context = self.context,
                  let sampler = self.sampler else {
                continuation.finish(throwing: NexusError.modelNotLoaded)
                return
            }

            self.cancelled = false
            self.isGenerating = true

            queue.async { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                defer {
                    Task { @MainActor in self.isGenerating = false }
                }

                do {
                    // Format messages using chat template
                    let prompt = self.formatPrompt(messages: messages, model: model)
                    let vocab = llama_model_get_vocab(model)

                    // Tokenize
                    guard let promptCStr = prompt.cString(using: .utf8) else {
                        continuation.finish(throwing: NexusError.inferenceError("Failed to encode prompt"))
                        return
                    }
                    let maxTokenCount = Int32(promptCStr.count + 256)
                    var tokens = [llama_token](repeating: 0, count: Int(maxTokenCount))
                    let nTokens = llama_tokenize(
                        vocab,
                        promptCStr,
                        Int32(promptCStr.count - 1),
                        &tokens,
                        maxTokenCount,
                        true,
                        true
                    )

                    guard nTokens > 0 else {
                        continuation.finish(throwing: NexusError.inferenceError("Tokenization failed"))
                        return
                    }

                    tokens = Array(tokens.prefix(Int(nTokens)))

                    // Clear KV cache
                    llama_memory_clear(llama_get_memory(context), true)

                    // Process prompt in batches
                    var batch = llama_batch_init(self.batchSize, 0, 1)
                    defer { llama_batch_free(batch) }

                    var pos: Int32 = 0
                    while pos < nTokens {
                        let remaining = nTokens - pos
                        let batchCount = min(remaining, self.batchSize)
                        llama_batch_clear(&batch)

                        for i in 0..<batchCount {
                            llama_batch_add(&batch, tokens[Int(pos + i)], pos + i, [0], i == batchCount - 1)
                        }

                        let status = llama_decode(context, batch)
                        guard status == 0 else {
                            continuation.finish(throwing: NexusError.inferenceError("Decode failed"))
                            return
                        }
                        pos += batchCount
                    }

                    // Generate tokens
                    var nGenerated: Int32 = 0
                    var utf8Buffer = Data()

                    while nGenerated < Int32(maxTokens) && !self.cancelled {
                        let token = llama_sampler_sample(sampler, context, -1)

                        if llama_vocab_is_eog(vocab, token) { break }

                        // Convert token to text
                        var buf = [CChar](repeating: 0, count: 256)
                        let len = llama_token_to_piece(vocab, token, &buf, 256, 0, true)

                        if len > 0 {
                            let tokenData = Data(bytes: buf, count: Int(len))
                            utf8Buffer.append(tokenData)

                            // Try to decode as UTF-8
                            if let text = String(data: utf8Buffer, encoding: .utf8) {
                                utf8Buffer.removeAll()
                                continuation.yield(text)
                            }
                        }

                        // Prepare next batch
                        llama_batch_clear(&batch)
                        llama_batch_add(&batch, token, pos, [0], true)
                        pos += 1

                        let status = llama_decode(context, batch)
                        guard status == 0 else { break }

                        llama_sampler_accept(sampler, token)
                        nGenerated += 1
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { [weak self] _ in
                self?.cancelGeneration()
            }
        }
    }

    func cancelGeneration() {
        cancelled = true
    }

    // MARK: - Prompt Formatting

    private func formatPrompt(messages: [ChatMessage], model: OpaquePointer) -> String {
        // Build a simple ChatML-style prompt
        var prompt = ""
        for message in messages {
            switch message.role {
            case .system:
                prompt += "<|im_start|>system\n\(message.content)<|im_end|>\n"
            case .user:
                prompt += "<|im_start|>user\n\(message.content)<|im_end|>\n"
            case .assistant:
                prompt += "<|im_start|>assistant\n\(message.content)<|im_end|>\n"
            }
        }
        prompt += "<|im_start|>assistant\n"
        return prompt
    }
}

// MARK: - llama_batch helper

private func llama_batch_add(
    _ batch: inout llama_batch,
    _ token: llama_token,
    _ pos: llama_pos,
    _ seqIds: [llama_seq_id],
    _ logits: Bool
) {
    let i = Int(batch.n_tokens)
    batch.token[i] = token
    batch.pos[i] = pos
    batch.n_seq_id[i] = Int32(seqIds.count)
    for (j, seqId) in seqIds.enumerated() {
        batch.seq_id[i]![j] = seqId
    }
    batch.logits[i] = logits ? 1 : 0
    batch.n_tokens += 1
}

private func llama_batch_clear(_ batch: inout llama_batch) {
    batch.n_tokens = 0
}
