import SwiftUI

struct ModelsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = ModelsViewModel()
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    if !appState.connectionState.isConnected {
                        notConnectedBanner
                    }

                    if viewModel.isLoading {
                        loadingSkeleton
                    } else if let error = viewModel.errorMessage {
                        errorBanner(error)
                    } else {
                        modelList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(NexusTheme.background)
            .navigationTitle("Models")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh(appState: appState) }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(NexusTheme.primary)
                            .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                            .animation(
                                viewModel.isLoading
                                    ? .linear(duration: 1).repeatForever(autoreverses: false)
                                    : .default,
                                value: viewModel.isLoading
                            )
                    }
                    .disabled(!appState.connectionState.isConnected)
                }
            }
            .task {
                if appState.connectionState.isConnected {
                    await viewModel.refresh(appState: appState)
                }
            }
        }
    }

    // MARK: - Not Connected

    private var notConnectedBanner: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(NexusTheme.textTertiary.opacity(0.08))
                    .frame(width: 72, height: 72)
                Image(systemName: "wifi.slash")
                    .font(.system(size: 28))
                    .foregroundStyle(NexusTheme.textTertiary)
            }

            Text("Not connected to server")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NexusTheme.textSecondary)

            Text("Connect in the Connect tab to browse and download models.")
                .font(.system(size: 13))
                .foregroundStyle(NexusTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .nexusGlassCard()
    }

    // MARK: - Loading Skeleton

    private var loadingSkeleton: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(NexusTheme.elevated)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(NexusTheme.elevated)
                            .frame(width: 140, height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(NexusTheme.elevated)
                            .frame(width: 90, height: 10)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 14)
                        .fill(NexusTheme.elevated)
                        .frame(width: 60, height: 28)
                }
                .padding(16)
                .background(NexusTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shimmer()
            }
        }
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(NexusTheme.error)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text("Failed to load models")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NexusTheme.error)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(NexusTheme.textSecondary)
            }

            Spacer()

            Button {
                Task { await viewModel.refresh(appState: appState) }
            } label: {
                Text("Retry")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NexusTheme.error)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(NexusTheme.error.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .nexusCard(glow: NexusTheme.error)
    }

    // MARK: - Model List

    @ViewBuilder
    private var modelList: some View {
        // Mode indicator
        HStack(spacing: 6) {
            Image(systemName: appState.inferenceMode == .onDevice ? "iphone" : "cloud.fill")
                .font(.system(size: 11))
            Text(appState.inferenceMode == .onDevice ? "On-Device Models" : "Server Models")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            let count = appState.inferenceMode == .onDevice ? viewModel.mobileModels.count : viewModel.serverModels.count
            Text("\(count) available")
                .font(.system(size: 12))
        }
        .foregroundStyle(NexusTheme.textTertiary)
        .padding(.horizontal, 4)

        switch appState.inferenceMode {
        case .onDevice:
            if viewModel.mobileModels.isEmpty {
                emptyState
            } else {
                ForEach(Array(viewModel.mobileModels.enumerated()), id: \.element.id) { index, model in
                    mobileModelCard(model)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity
                        ))
                }
            }
        case .server:
            if viewModel.serverModels.isEmpty {
                emptyState
            } else {
                ForEach(Array(viewModel.serverModels.enumerated()), id: \.element.id) { index, model in
                    serverModelCard(model)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity
                        ))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(NexusTheme.textTertiary.opacity(0.08))
                    .frame(width: 64, height: 64)
                Image(systemName: "tray")
                    .font(.system(size: 24))
                    .foregroundStyle(NexusTheme.textTertiary)
            }
            Text("No models available")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(NexusTheme.textSecondary)
            Text("Check your server or switch inference mode.")
                .font(.system(size: 12))
                .foregroundStyle(NexusTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .nexusCard()
    }

    // MARK: - Mobile Model Card

    private func mobileModelCard(_ model: MobileModel) -> some View {
        let isDownloaded = appState.downloadManager.isDownloaded(model.file)
        let downloadProgress = appState.downloadManager.progress[model.file]
        let isSelected = appState.selectedModelFile == model.file

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Model icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            isDownloaded
                                ? NexusTheme.accent.opacity(0.12)
                                : NexusTheme.primary.opacity(0.12)
                        )
                    Image(systemName: isDownloaded ? "checkmark.circle.fill" : "cube.box")
                        .font(.system(size: 18))
                        .foregroundStyle(isDownloaded ? NexusTheme.accent : NexusTheme.primary)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 5) {
                    Text(model.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NexusTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(model.quantization)
                            .nexusBadge(color: NexusTheme.accent)

                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 9))
                            Text("\(model.sizeMB) MB")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(NexusTheme.textTertiary)

                        HStack(spacing: 3) {
                            Image(systemName: "memorychip")
                                .font(.system(size: 9))
                            Text("\(model.recommendedRamGB) GB")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(NexusTheme.textTertiary)
                    }
                }

                Spacer()

                // Action buttons
                if isDownloaded {
                    HStack(spacing: 8) {
                        Button {
                            viewModel.selectMobileModel(model, appState: appState)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isSelected ? "checkmark" : "bubble.left.fill")
                                    .font(.system(size: 11))
                                Text(isSelected ? "Active" : "Chat")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(isSelected ? NexusTheme.accent : NexusTheme.primary)
                                    .shadow(
                                        color: (isSelected ? NexusTheme.accent : NexusTheme.primary).opacity(0.25),
                                        radius: 4, y: 2
                                    )
                            )
                        }

                        Button {
                            viewModel.deleteModel(model, appState: appState)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundStyle(NexusTheme.textTertiary)
                                .frame(width: 30, height: 30)
                                .background(NexusTheme.inputBackground)
                                .clipShape(Circle())
                        }
                    }
                } else if downloadProgress != nil {
                    Button {
                        appState.downloadManager.cancelDownload(for: model.file)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(NexusTheme.error)
                            .frame(width: 30, height: 30)
                            .background(NexusTheme.error.opacity(0.1))
                            .clipShape(Circle())
                    }
                } else {
                    Button {
                        viewModel.downloadModel(model, appState: appState)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 11))
                            Text("Get")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(NexusTheme.primary)
                                .shadow(color: NexusTheme.primary.opacity(0.25), radius: 4, y: 2)
                        )
                    }
                }
            }

            // Download progress
            if let progress = downloadProgress {
                VStack(spacing: 5) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(NexusTheme.inputBackground)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(NexusTheme.accentGradient)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        let downloadedMB = Int(Double(model.sizeMB) * progress)
                        Text("\(downloadedMB) / \(model.sizeMB) MB")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(NexusTheme.textTertiary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(NexusTheme.primary)
                    }
                }
            }
        }
        .nexusCard(glow: isSelected ? NexusTheme.accent : nil)
    }

    // MARK: - Server Model Card

    private func serverModelCard(_ model: ServerModel) -> some View {
        let isSelected = appState.selectedModelFile == model.file

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(NexusTheme.primary.opacity(0.12))
                Image(systemName: "cloud.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(NexusTheme.primary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 5) {
                Text(model.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NexusTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(model.method)
                        .nexusBadge(color: NexusTheme.primary)

                    HStack(spacing: 3) {
                        Image(systemName: "doc")
                            .font(.system(size: 9))
                        Text("\(model.sizeMB) MB")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(NexusTheme.textTertiary)
                }
            }

            Spacer()

            Button {
                viewModel.selectServerModel(model, appState: appState)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isSelected ? "checkmark" : "bubble.left.fill")
                        .font(.system(size: 11))
                    Text(isSelected ? "Active" : "Chat")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? NexusTheme.accent : NexusTheme.primary)
                        .shadow(
                            color: (isSelected ? NexusTheme.accent : NexusTheme.primary).opacity(0.25),
                            radius: 4, y: 2
                        )
                )
            }
        }
        .nexusCard(glow: isSelected ? NexusTheme.accent : nil)
    }
}
