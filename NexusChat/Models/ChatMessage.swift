import Foundation
import UIKit

/// A single chat message with optional image attachment.
struct ChatMessage: Identifiable {
    let id: UUID
    let role: Role
    var content: String
    let imageData: Data?
    let timestamp: Date

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    init(role: Role, content: String, imageData: Data? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.imageData = imageData
        self.timestamp = Date()
    }

    var isUser: Bool { role == .user }

    /// Convert stored JPEG data back to UIImage.
    var image: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }

    /// True while the assistant is still inside an open `<think>` block.
    var isThinking: Bool {
        let opens = content.components(separatedBy: "<think>").count - 1
        let closes = content.components(separatedBy: "</think>").count - 1
        return opens > closes
    }

    /// Parsed content that separates visible text from thinking blocks.
    struct ParsedContent {
        let visibleText: String
        let thinkingBlocks: [String]
    }

    var parsedContent: ParsedContent {
        var visible = content
        var blocks: [String] = []

        while let openRange = visible.range(of: "<think>") {
            let before = String(visible[visible.startIndex..<openRange.lowerBound])
            if let closeRange = visible.range(of: "</think>") {
                let thinking = String(visible[openRange.upperBound..<closeRange.lowerBound])
                blocks.append(thinking.trimmingCharacters(in: .whitespacesAndNewlines))
                visible = before + String(visible[closeRange.upperBound...])
            } else {
                // Open <think> without close — still streaming
                let thinking = String(visible[openRange.upperBound...])
                blocks.append(thinking.trimmingCharacters(in: .whitespacesAndNewlines))
                visible = before
                break
            }
        }

        return ParsedContent(
            visibleText: visible.trimmingCharacters(in: .whitespacesAndNewlines),
            thinkingBlocks: blocks
        )
    }
}
