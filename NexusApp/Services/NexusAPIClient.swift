import Foundation
#if canImport(UIKit)
import UIKit
#endif

actor NexusAPIClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private var authToken: String?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.authToken = nil
    }

    // MARK: - Authentication

    func login(
        serverUrl: String,
        username: String = "admin",
        password: String = "admin-nexus-qpi"
    ) async throws {
        guard let url = URL(string: "\(serverUrl)/api/auth/login") else {
            throw NexusError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = try JSONSerialization.data(withJSONObject: [
            "username": username,
            "password": password
        ])
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = json["token"] as? String {
            authToken = token
        }
    }

    func getAuthToken() -> String? {
        return authToken
    }

    private func authorizedRequest(_ request: URLRequest) -> URLRequest {
        var req = request
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    // MARK: - Device Registration

    func register(serverUrl: String) async throws -> RegisterResponse {
        guard let url = URL(string: "\(serverUrl)/api/mobile/register") else {
            throw NexusError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let hardware = DeviceInfo.current
        let body = RegisterRequest(
            name: hardware.name,
            platform: hardware.platform,
            hardware: HardwareInfo(
                cpuModel: hardware.cpuModel,
                cpuCores: hardware.cpuCores,
                ramGB: hardware.ramGB,
                storageGB: hardware.storageGB
            )
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: authorizedRequest(request))
        try validateResponse(response)
        return try decoder.decode(RegisterResponse.self, from: data)
    }

    // MARK: - Models

    func fetchMobileModels(serverUrl: String) async throws -> [MobileModel] {
        guard let url = URL(string: "\(serverUrl)/api/mobile/models") else {
            throw NexusError.invalidResponse
        }
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: authorizedRequest(request))
        try validateResponse(response)
        let result = try decoder.decode(MobileModelsResponse.self, from: data)
        return result.models
    }

    func fetchServerModels(serverUrl: String) async throws -> [ServerModel] {
        guard let url = URL(string: "\(serverUrl)/api/chat/models") else {
            throw NexusError.invalidResponse
        }
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: authorizedRequest(request))
        try validateResponse(response)
        let result = try decoder.decode(ServerModelsResponse.self, from: data)
        return result.models
    }

    // MARK: - Cloud Inference (SSE)

    nonisolated func streamCloudInference(
        serverUrl: String,
        modelFile: String,
        method: String,
        messages: [[String: String]],
        maxTokens: Int = 512,
        authToken: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = URL(string: "\(serverUrl)/api/chat") else {
                        continuation.finish(throwing: NexusError.invalidResponse)
                        return
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    if let token = authToken {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }

                    let body: [String: Any] = [
                        "model": modelFile,
                        "method": method,
                        "messages": messages,
                        "maxTokens": maxTokens
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode != 200 {
                        continuation.finish(throwing: NexusError.serverError(httpResponse.statusCode))
                        return
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        guard line.hasPrefix("data: ") else { continue }
                        let data = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)

                        if data == "[DONE]" { break }

                        guard let jsonData = data.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                        else { continue }

                        let type = json["type"] as? String
                        if type == "error" {
                            let msg = json["message"] as? String ?? "Unknown error"
                            continuation.finish(throwing: NexusError.inferenceError(msg))
                            return
                        }

                        if let text = json["text"] as? String ?? json["content"] as? String {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Metrics

    func reportMetrics(serverUrl: String, payload: MetricsUpdatePayload) async throws {
        guard let url = URL(string: "\(serverUrl)/api/mobile/ws") else {
            throw NexusError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await session.data(for: authorizedRequest(request))
        try validateResponse(response)
    }

    func reportInferenceMetrics(serverUrl: String, payload: InferenceMetricsPayload) async throws {
        guard let url = URL(string: "\(serverUrl)/api/mobile/ws") else {
            throw NexusError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await session.data(for: authorizedRequest(request))
        try validateResponse(response)
    }

    // MARK: - SSE Event Listener

    nonisolated func listenForEvents(
        serverUrl: String,
        deviceId: String,
        authToken: String? = nil
    ) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var retryCount = 0
                let maxRetries = 10

                while !Task.isCancelled && retryCount < maxRetries {
                    do {
                        guard let url = URL(string: "\(serverUrl)/api/mobile/ws?deviceId=\(deviceId)") else {
                            continuation.finish(throwing: NexusError.invalidResponse)
                            return
                        }
                        var request = URLRequest(url: url)
                        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                        if let token = authToken {
                            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                        }
                        request.timeoutInterval = .infinity

                        let (bytes, _) = try await URLSession.shared.bytes(for: request)
                        retryCount = 0

                        var eventType: String?
                        for try await line in bytes.lines {
                            if Task.isCancelled { break }

                            if line.hasPrefix("event: ") {
                                eventType = String(line.dropFirst(7))
                            } else if line.hasPrefix("data: ") {
                                let data = String(line.dropFirst(6))
                                if let type = eventType {
                                    continuation.yield(SSEEvent(event: type, data: data))
                                }
                                eventType = nil
                            }
                        }
                    } catch {
                        if Task.isCancelled { break }
                        retryCount += 1
                        let delay = min(5.0 * Double(retryCount), 30.0)
                        try? await Task.sleep(for: .seconds(delay))
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Helpers

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NexusError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NexusError.serverError(httpResponse.statusCode)
        }
    }
}

// MARK: - Types

struct SSEEvent {
    let event: String
    let data: String
}

enum NexusError: LocalizedError, Sendable {
    case invalidResponse
    case serverError(Int)
    case inferenceError(String)
    case modelNotLoaded
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid server response"
        case .serverError(let code): "Server error (\(code))"
        case .inferenceError(let msg): msg
        case .modelNotLoaded: "No model loaded"
        case .downloadFailed(let msg): "Download failed: \(msg)"
        }
    }
}

// MARK: - Device Info

struct DeviceInfo {
    let name: String
    let platform: String
    let cpuModel: String
    let cpuCores: Int
    let ramGB: Int
    let storageGB: Int

    static var current: DeviceInfo {
        #if os(iOS)
        let device = UIDevice.current
        let name = device.name
        let platform = "iOS \(device.systemVersion)"
        #else
        let name = Host.current().localizedName ?? "Mac"
        let platform = "macOS"
        #endif

        let cpuCores = ProcessInfo.processInfo.processorCount
        let ramGB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))

        let storageGB: Int
        if let attrs = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        ), let totalSize = attrs[.systemSize] as? Int64 {
            storageGB = Int(totalSize / (1024 * 1024 * 1024))
        } else {
            storageGB = 0
        }

        return DeviceInfo(
            name: name,
            platform: platform,
            cpuModel: "Apple Silicon",
            cpuCores: cpuCores,
            ramGB: ramGB,
            storageGB: storageGB
        )
    }
}
