import Foundation

struct MobileModel: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let file: String
    let sizeBytes: Int64
    let sizeMB: Int
    let quantization: String
    let method: String
    let downloadUrl: String
    let recommendedRamGB: Int
    let mobileCompatible: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, file, quantization, method
        case sizeBytes = "size_bytes"
        case sizeMB = "size_mb"
        case downloadUrl = "download_url"
        case recommendedRamGB = "recommended_ram_gb"
        case mobileCompatible = "mobile_compatible"
    }
}

struct MobileModelsResponse: Codable {
    let models: [MobileModel]
}

struct ServerModel: Codable, Identifiable, Equatable {
    var id: String { file }
    let name: String
    let file: String
    let method: String
    let sizeMB: Int
}

struct ServerModelsResponse: Codable {
    let models: [ServerModel]
}
