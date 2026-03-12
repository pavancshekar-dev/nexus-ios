import Foundation

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var label: String {
        switch self {
        case .disconnected: "Offline"
        case .connecting: "Connecting..."
        case .connected: "Online"
        case .error(let msg): "Error: \(msg)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

enum InferenceMode: String, CaseIterable, Codable {
    case onDevice = "on_device"
    case server = "server"

    var label: String {
        switch self {
        case .onDevice: "On-Device"
        case .server: "Cloud"
        }
    }
}

struct RegisterRequest: Codable {
    let name: String
    let platform: String
    let hardware: HardwareInfo
}

struct HardwareInfo: Codable {
    let cpuModel: String
    let cpuCores: Int
    let ramGB: Int
    let storageGB: Int
}

struct RegisterResponse: Codable {
    let id: String
    let message: String
    let wsEndpoint: String
}
