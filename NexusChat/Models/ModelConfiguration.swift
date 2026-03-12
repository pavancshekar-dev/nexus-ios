import Foundation

/// On-device MLX models available for local inference.
enum AppModel: String, CaseIterable, Identifiable {
    case qwen35_08b = "Qwen 3.5 0.8B"
    case qwen3_17b  = "Qwen 3 1.7B"
    case lfm_12b    = "LFM 1.2B Thinking"
    case gemma3_1b  = "Gemma 3 1B"

    var id: String { rawValue }

    /// HuggingFace repo ID for the 4-bit MLX model.
    var huggingFaceID: String {
        switch self {
        case .qwen35_08b: return "mlx-community/Qwen3.5-0.8B-4bit"
        case .qwen3_17b:  return "mlx-community/Qwen3-1.7B-4bit"
        case .lfm_12b:    return "LiquidAI/LFM2.5-1.2B-Thinking-MLX-4bit"
        case .gemma3_1b:  return "mlx-community/gemma-3-1b-it-4bit"
        }
    }

    /// Approximate download size in GB.
    var estimatedSizeGB: Double {
        switch self {
        case .qwen35_08b: return 0.5
        case .qwen3_17b:  return 1.0
        case .lfm_12b:    return 0.7
        case .gemma3_1b:  return 0.6
        }
    }

    /// Whether this model supports vision (image) inputs.
    var supportsVision: Bool {
        switch self {
        case .qwen35_08b: return true
        default: return false
        }
    }
}
