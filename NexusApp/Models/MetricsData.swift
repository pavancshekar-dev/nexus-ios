import Foundation

struct SystemMetrics: Codable {
    var cpuUsage: Int
    var memoryUsage: Int
    var temperature: Int
    var batteryLevel: Int
}

struct InferenceMetrics: Codable {
    var tokensPerSec: Double
    var tokenCount: Int
    var elapsed: Double
    var memoryUsage: Int
    var cpuUsage: Int
    var batteryLevel: Int
    var activeModel: String
    var inferenceMode: String
    var engineType: String
    var timestamp: Int64
}

struct MetricsUpdatePayload: Codable {
    let deviceId: String
    let type: String
    let data: MetricsUpdateData
}

struct MetricsUpdateData: Codable {
    let cpuUsage: Int
    let memoryUsage: Int
    let temperature: Int
    let batteryLevel: Int
    let tokensPerSec: Double
    let activeModel: String
    let totalInferences: Int
    let totalTokens: Int
    let engineType: String
}

struct InferenceMetricsPayload: Codable {
    let deviceId: String
    let type: String
    let data: InferenceMetrics
}
