import SwiftUI
import UIKit

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                chatHeader
                warningBanner
                messagesList
                inputBar
            }
            .background(NexusTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    modeBadge
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if viewModel.isGenerating || viewModel.tokensPerSec > 0 {
                            tpsIndicator
                        }
                        Button {
                            viewModel.clearChat()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(NexusTheme.textTertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Mode Badge

    private var modeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: appState.inferenceMode == .onDevice ? "iphone" : "cloud.fill")
                .font(.system(size: 10))
            Text(appState.inferenceMode.label)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(appState.inferenceMode == .onDevice ? NexusTheme.accent : NexusTheme.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            (appState.inferenceMode == .onDevice ? NexusTheme.accent : NexusTheme.primary).opacity(0.12)
        )
        .clipShape(Capsule())
    }

    // MARK: - TPS Indicator

    private var tpsIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 9))
            Text(String(format: "%.1f t/s", viewModel.tokensPerSec))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(NexusTheme.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(NexusTheme.accent.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Header

    private var chatHeader: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(NexusTheme.primary.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "cpu")
                            .font(.system(size: 14))
                            .foregroundStyle(NexusTheme.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.selectedModelName ?? "No Model")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NexusTheme.textPrimary)
                            .lineLimit(1)

                        if appState.selectedModelFile != nil {
                            Text(appState.selectedModelMethod ?? "")
                                .font(.system(size: 11))
                                .foregroundStyle(NexusTheme.textTertiary)
                        } else {
                            Text("Select a model in the Models tab")
                                .font(.system(size: 11))
                                .foregroundStyle(NexusTheme.textTertiary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Gradient accent line
            Rectangle()
                .fill(NexusTheme.accentGradient)
                .frame(height: 1.5)
                .opacity(0.6)
        }
        .background(NexusTheme.surface)
    }

    // MARK: - Warning Banner

    @ViewBuilder
    private var warningBanner: some View {
        let mem = appState.metricsReporter.latestMetrics.memoryUsage
        let cpu = appState.metricsReporter.latestMetrics.cpuUsage
        let isCritical = mem > 95 || cpu > 90

        if mem > 80 || cpu > 75 {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))

                if mem > 80 {
                    metricChip("RAM \(mem)%")
                }
                if cpu > 75 {
                    metricChip("CPU \(cpu)%")
                }

                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isCritical ? NexusTheme.errorGradient : NexusTheme.accentGradient)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func metricChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    // Welcome message when empty
                    if viewModel.messages.filter({ $0.role != .system }).isEmpty {
                        welcomeCard
                    }

                    ForEach(viewModel.messages.filter { $0.role != .system }) { message in
                        messageBubble(message)
                            .id(message.id)
                    }

                    // Typing indicator
                    if viewModel.isGenerating,
                       let last = viewModel.messages.last,
                       last.role == .assistant,
                       last.content.isEmpty {
                        typingIndicator
                            .id("typing")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.last?.content) {
                if let lastId = viewModel.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var welcomeCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32))
                .foregroundStyle(NexusTheme.textTertiary)

            Text("Start a conversation")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NexusTheme.textSecondary)

            Text(appState.selectedModelFile != nil
                 ? "Type a message below to begin."
                 : "Select a model in the Models tab first.")
                .font(.system(size: 13))
                .foregroundStyle(NexusTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(NexusTheme.textTertiary)
                        .frame(width: 6, height: 6)
                        .offset(y: typingDotOffset(index: i))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(NexusTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )

            Spacer(minLength: 80)
        }
    }

    @State private var typingAnimationPhase: CGFloat = 0

    private func typingDotOffset(index: Int) -> CGFloat {
        // Simple bounce — each dot offset by phase
        let phase = typingAnimationPhase + CGFloat(index) * 0.3
        return sin(phase * .pi * 2) * 4
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 3) {
                Text(message.content.isEmpty && message.role == .assistant ? " " : message.content)
                    .font(.system(size: 15))
                    .foregroundStyle(NexusTheme.textPrimary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        if message.role == .user {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [NexusTheme.primary.opacity(0.35), NexusTheme.primary.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(NexusTheme.primary.opacity(0.2), lineWidth: 0.5)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(NexusTheme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
                        }
                    }
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }

                Text(message.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(NexusTheme.textTertiary)
                    .padding(.horizontal, 4)
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.white.opacity(0.04))

            HStack(alignment: .bottom, spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Ask anything...", text: $viewModel.inputText, axis: .vertical)
                        .lineLimit(1...5)
                        .textFieldStyle(.plain)
                        .foregroundStyle(NexusTheme.textPrimary)
                        .focused($isInputFocused)
                        .onSubmit {
                            if canSend {
                                viewModel.send(appState: appState)
                            }
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(NexusTheme.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(
                            isInputFocused ? NexusTheme.primary.opacity(0.3) : Color.white.opacity(0.04),
                            lineWidth: 1
                        )
                )

                if viewModel.isGenerating {
                    Button {
                        viewModel.stop(appState: appState)
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(NexusTheme.error)
                                    .shadow(color: NexusTheme.error.opacity(0.3), radius: 4, y: 2)
                            )
                    }
                } else {
                    Button {
                        viewModel.send(appState: appState)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(canSend ? NexusTheme.primary : NexusTheme.textTertiary.opacity(0.3))
                                    .shadow(color: canSend ? NexusTheme.primary.opacity(0.3) : .clear, radius: 4, y: 2)
                            )
                    }
                    .disabled(!canSend)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(NexusTheme.surface)
        }
    }

    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && appState.selectedModelFile != nil
        && !viewModel.isGenerating
    }
}
