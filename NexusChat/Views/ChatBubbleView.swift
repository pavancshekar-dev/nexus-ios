import SwiftUI

/// Renders a single message bubble with thinking block support.
struct ChatBubbleView: View {
    let message: ChatMessage
    @State private var showThinking = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser { Spacer(minLength: 40) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                // Image attachment
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                let parsed = message.parsedContent

                // Thinking blocks (collapsible)
                if !parsed.thinkingBlocks.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showThinking.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showThinking ? "brain.head.profile.fill" : "brain.head.profile")
                                .font(.caption2)
                            Text(message.isThinking ? "Thinking..." : "Thought process")
                                .font(.caption2)
                            if message.isThinking {
                                ProgressView()
                                    .controlSize(.mini)
                            }
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }

                    if showThinking {
                        ForEach(Array(parsed.thinkingBlocks.enumerated()), id: \.offset) { _, block in
                            Text(block)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }

                // Visible text
                if !parsed.visibleText.isEmpty {
                    Text(parsed.visibleText)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(message.isUser ? Color.accentColor : Color(.systemGray6))
                        .foregroundStyle(message.isUser ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else if message.role == .assistant && message.content.isEmpty {
                    // Empty assistant = still loading
                    EmptyView()
                }

                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }

            if !message.isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal)
    }
}
