import Foundation

/// Handles communication with the Nexus server: auth, device registration, and SSE streaming.
@Observable
@MainActor
final class NexusAPIService {
    var serverURL: String = ""
    var authToken: String?
    var deviceId: String?
    var isConnected: Bool = false
    var errorMessage: String?

    private var sseTask: Task<Void, Never>?

    // MARK: - Auth

    func login(
        username: String = "admin",
        password: String = "admin-nexus-qpi"
    ) async throws {
        guard let url = URL(string: "\(serverURL)/api/auth/login") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["username": username, "password": password])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.authFailed
        }

        let result = try JSONDecoder().decode(AuthResponse.self, from: data)
        authToken = result.token
        isConnected = true
        errorMessage = nil
    }

    // MARK: - Device Registration

    func registerDevice() async throws {
        guard let token = authToken,
              let url = URL(string: "\(serverURL)/api/mobile/register") else {
            throw APIError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let deviceInfo = DeviceRegistration(
            name: UIDevice.current.name,
            platform: "iOS \(UIDevice.current.systemVersion)",
            hardware: HardwareInfo(
                cpuModel: "Apple Silicon",
                cpuCores: ProcessInfo.processInfo.processorCount,
                ramGB: Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)),
                storageGB: getAvailableStorageGB()
            )
        )

        request.httpBody = try JSONEncoder().encode(deviceInfo)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.registrationFailed
        }

        let result = try JSONDecoder().decode(RegisterResponse.self, from: data)
        deviceId = result.deviceId
    }

    // MARK: - SSE Streaming for Server Inference

    func streamChat(
        messages: [[String: String]],
        model: String,
        method: String,
        onToken: @Sendable @escaping (String) -> Void,
        onMetrics: @Sendable @escaping (ChatMetrics) -> Void,
        onError: @Sendable @escaping (String) -> Void,
        onComplete: @Sendable @escaping () -> Void = {}
    ) {
        sseTask?.cancel()
        sseTask = Task.detached { [serverURL, authToken] in
            guard let url = URL(string: "\(serverURL)/api/chat") else {
                await MainActor.run { onError("Invalid server URL") }
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token = authToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let body: [String: Any] = [
                "model": model,
                "method": method,
                "messages": messages,
                "maxTokens": 512,
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    await MainActor.run { onError("Server returned error") }
                    return
                }

                var eventType = ""
                for try await line in bytes.lines {
                    if Task.isCancelled { break }

                    if line.hasPrefix("event: ") {
                        eventType = String(line.dropFirst(7))
                    } else if line.hasPrefix("data: ") {
                        let jsonStr = String(line.dropFirst(6))
                        guard let jsonData = jsonStr.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                            continue
                        }

                        switch eventType {
                        case "token":
                            if let text = json["text"] as? String {
                                await MainActor.run { onToken(text) }
                            }
                        case "metrics":
                            if let tokens = json["tokens_generated"] as? Int,
                               let timeMs = json["time_ms"] as? Double,
                               let tps = json["tokens_per_sec"] as? Double {
                                let metrics = ChatMetrics(tokensGenerated: tokens, timeMs: timeMs, tokensPerSec: tps)
                                await MainActor.run { onMetrics(metrics) }
                            }
                        case "error":
                            if let msg = json["message"] as? String {
                                await MainActor.run { onError(msg) }
                            }
                        default:
                            break
                        }
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run { onError(error.localizedDescription) }
                }
            }
            await MainActor.run { onComplete() }
        }
    }

    func cancelStream() {
        sseTask?.cancel()
        sseTask = nil
    }

    func disconnect() {
        cancelStream()
        authToken = nil
        deviceId = nil
        isConnected = false
    }

    // MARK: - Helpers

    private func getAvailableStorageGB() -> Int {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let path = paths.first else { return 0 }
        let values = try? path.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let bytes = values?.volumeAvailableCapacityForImportantUsage ?? 0
        return Int(bytes / (1024 * 1024 * 1024))
    }
}

// MARK: - Types

import UIKit

enum APIError: LocalizedError {
    case invalidURL
    case authFailed
    case notAuthenticated
    case registrationFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .authFailed: return "Authentication failed"
        case .notAuthenticated: return "Not authenticated"
        case .registrationFailed: return "Device registration failed"
        }
    }
}

struct AuthResponse: Decodable {
    let token: String
}

struct RegisterResponse: Decodable {
    let deviceId: String
}

struct DeviceRegistration: Encodable {
    let name: String
    let platform: String
    let hardware: HardwareInfo
}

struct HardwareInfo: Encodable {
    let cpuModel: String
    let cpuCores: Int
    let ramGB: Int
    let storageGB: Int
}

struct ChatMetrics: Sendable {
    let tokensGenerated: Int
    let timeMs: Double
    let tokensPerSec: Double
}
