import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showClearAlert = false
    @State private var cacheCleared = false
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    connectionStatusCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 15)

                    serverSection

                    storageSection

                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(NexusTheme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Connection Status

    private var connectionStatusCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        appState.connectionState.isConnected
                            ? NexusTheme.accent.opacity(0.12)
                            : NexusTheme.textTertiary.opacity(0.12)
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: appState.connectionState.isConnected ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        appState.connectionState.isConnected ? NexusTheme.accent : NexusTheme.textTertiary
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(appState.connectionState.isConnected ? "Connected to Nexus" : "Not Connected")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NexusTheme.textPrimary)
                Text(appState.connectionState.isConnected
                     ? "Device registered and reporting metrics"
                     : "Go to Connect tab to set up")
                    .font(.system(size: 12))
                    .foregroundStyle(NexusTheme.textTertiary)
            }

            Spacer()

            PulsingDot(
                color: appState.connectionState.isConnected ? NexusTheme.accent : NexusTheme.textTertiary,
                isActive: appState.connectionState.isConnected
            )
        }
        .nexusCard(glow: appState.connectionState.isConnected ? NexusTheme.accent : nil)
    }

    // MARK: - Server

    private var serverSection: some View {
        ExpandableSection(title: "Server", icon: "server.rack", iconColor: NexusTheme.primary) {
            VStack(spacing: 0) {
                settingsRow(
                    "URL",
                    appState.serverUrl.isEmpty ? "Not set" : appState.serverUrl,
                    icon: "link",
                    valueColor: appState.serverUrl.isEmpty ? NexusTheme.textTertiary : NexusTheme.textPrimary
                )
                settingsDivider
                settingsRow(
                    "Device ID",
                    appState.deviceId ?? "Not registered",
                    icon: "person.crop.circle",
                    valueColor: appState.deviceId == nil ? NexusTheme.textTertiary : NexusTheme.textPrimary
                )
                settingsDivider
                settingsRow(
                    "Status",
                    appState.connectionState.label,
                    icon: "circle.fill",
                    valueColor: appState.connectionState.isConnected ? NexusTheme.accent : NexusTheme.textSecondary
                )
                settingsDivider
                settingsRow("Inference", appState.inferenceMode.label, icon: "bolt.fill")
            }
            .background(NexusTheme.inputBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        ExpandableSection(title: "Storage", icon: "internaldrive", iconColor: NexusTheme.accent) {
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    let downloadedCount = appState.downloadManager.downloadedModels.count
                    settingsRow("Downloaded Models", "\(downloadedCount)", icon: "arrow.down.circle")
                    settingsDivider
                    settingsRow("Location", "Documents/models/", icon: "folder")
                    settingsDivider
                    settingsRow(
                        "Free Space",
                        String(format: "%.1f GB", appState.freeStorageGB),
                        icon: "chart.pie",
                        valueColor: appState.freeStorageGB < 1.0 ? NexusTheme.error : NexusTheme.textPrimary
                    )
                }
                .background(NexusTheme.inputBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Clear cache button
                Button {
                    showClearAlert = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                        Text("Clear Model Cache")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(NexusTheme.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(NexusTheme.error.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(NexusTheme.error.opacity(0.15), lineWidth: 1)
                            )
                    )
                }
                .alert("Clear Model Cache", isPresented: $showClearAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear All", role: .destructive) {
                        clearModelCache()
                    }
                } message: {
                    Text("This will delete all downloaded models. You'll need to re-download them.")
                }

                if cacheCleared {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Cache cleared successfully")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(NexusTheme.accent)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        ExpandableSection(title: "About", icon: "info.circle", iconColor: NexusTheme.textSecondary) {
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    settingsRow("App", "QpiAI Nexus", icon: "atom")
                    settingsDivider
                    settingsRow("Version", "1.0.0", icon: "tag")
                    settingsDivider
                    settingsRow("Platform", "iOS (SwiftUI)", icon: "apple.logo")
                    settingsDivider
                    settingsRow("Engine", "llama.cpp (C interop)", icon: "cpu")
                    settingsDivider
                    settingsRow(
                        "Build",
                        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
                        icon: "hammer"
                    )
                }
                .background(NexusTheme.inputBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Credits
                VStack(spacing: 4) {
                    Text("Built with SwiftUI & llama.cpp")
                        .font(.system(size: 11))
                        .foregroundStyle(NexusTheme.textTertiary)
                    Text("QpiAI")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NexusTheme.titleGradient)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Reusable Row

    private var settingsDivider: some View {
        Divider().overlay(Color.white.opacity(0.04))
    }

    private func settingsRow(
        _ label: String,
        _ value: String,
        icon: String,
        valueColor: Color = NexusTheme.textPrimary
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(NexusTheme.textTertiary)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(NexusTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func clearModelCache() {
        let modelsDir = ModelDownloadManager.modelsDirectory
        if let files = try? FileManager.default.contentsOfDirectory(atPath: modelsDir.path) {
            for file in files {
                try? FileManager.default.removeItem(at: modelsDir.appendingPathComponent(file))
            }
        }
        appState.downloadManager.downloadedModels.removeAll()
        UserDefaults.standard.removeObject(forKey: "downloadedModels")

        withAnimation(.spring(response: 0.3)) {
            cacheCleared = true
        }

        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                withAnimation { cacheCleared = false }
            }
        }
    }
}
