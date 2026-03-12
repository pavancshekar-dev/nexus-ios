import SwiftUI

/// Main chat interface with streaming message display.
struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var messageText = ""
    @State private var selectedImageData: Data?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if viewModel.messages.isEmpty {
                                emptyState
                            }

                            ForEach(viewModel.messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }

                            // Loading indicator
                            if viewModel.isGenerating,
                               let last = viewModel.messages.last,
                               last.role == .assistant,
                               last.content.isEmpty {
                                HStack {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Thinking...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: viewModel.messages.last?.content) { _, _ in
                        if let lastId = viewModel.messages.last?.id {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }

                // Error banner
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                        Spacer()
                        Button("Dismiss") { viewModel.errorMessage = nil }
                            .font(.caption2)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.1))
                }

                // Performance info
                if let info = viewModel.lastInfoSummary {
                    HStack {
                        Image(systemName: "speedometer")
                            .font(.caption2)
                        Text(info)
                            .font(.caption2)
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }

                Divider()

                // Input
                MessageInputView(
                    text: $messageText,
                    imageData: $selectedImageData,
                    isGenerating: viewModel.isGenerating,
                    onSend: {
                        let text = messageText
                        let img = selectedImageData
                        messageText = ""
                        selectedImageData = nil
                        Task { await viewModel.send(text, imageData: img) }
                    },
                    onStop: {
                        viewModel.stopGeneration()
                    }
                )
            }
            .navigationTitle("Nexus Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    modeIndicator
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.clearChat()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
            }
        }
    }

    private var modeIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(viewModel.inferenceMode == .local
                      ? (viewModel.isModelLoaded ? .green : .orange)
                      : (viewModel.apiService.isConnected ? .green : .red))
                .frame(width: 6, height: 6)
            Text(viewModel.inferenceMode == .local ? "Local" : "Server")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 80)
            Image(systemName: "message.badge.waveform")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("Start a conversation")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(viewModel.inferenceMode == .local
                 ? "Using \(viewModel.selectedModel.rawValue) on-device"
                 : "Connected to Nexus server")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }
}
