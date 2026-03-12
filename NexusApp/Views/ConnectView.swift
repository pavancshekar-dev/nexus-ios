import SwiftUI

struct ConnectView: View {
    @Environment(AppState.self) private var appState
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    heroCard
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)

                    quickStats
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)

                    serverCard
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)

                    inferenceModeCard
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)

                    connectionLogSection

                    deviceInfoSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(NexusTheme.background)
            .navigationTitle("")
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 14) {
            ZStack {
                // Glow behind icon
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NexusTheme.primary.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "atom")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(NexusTheme.titleGradient)
                    .symbolEffect(.pulse, options: .repeating, isActive: appState.connectionState.isConnected)
            }

            Text("QpiAI Nexus")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(NexusTheme.titleGradient)

            Text("Your AI, Running On Your Device")
                .font(.system(size: 14))
                .foregroundStyle(NexusTheme.textSecondary)

            statusBadge

            HStack(spacing: 8) {
                featureBadge("Swift Engine", color: NexusTheme.accent, icon: "swift")
                featureBadge("Zero Latency", color: NexusTheme.primary, icon: "bolt.fill")
                featureBadge("Full Privacy", color: NexusTheme.secondary, icon: "lock.fill")
            }
        }
        .frame(maxWidth: .infinity)
        .nexusGlassCard()
    }

    private func featureBadge(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
        }
        .nexusBadge(color: color)
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            PulsingDot(
                color: appState.connectionState.isConnected ? NexusTheme.accent : NexusTheme.textTertiary,
                isActive: appState.connectionState.isConnected
            )

            Text(appState.connectionState.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    appState.connectionState.isConnected
                        ? NexusTheme.accent
                        : NexusTheme.textSecondary
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(
                    (appState.connectionState.isConnected ? NexusTheme.accent : NexusTheme.textTertiary)
                        .opacity(0.1)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            (appState.connectionState.isConnected ? NexusTheme.accent : NexusTheme.textTertiary)
                                .opacity(0.2),
                            lineWidth: 0.5
                        )
                )
        )
    }

    // MARK: - Quick Stats

    private var quickStats: some View {
        HStack(spacing: 10) {
            quickStatChip(
                icon: "internaldrive",
                label: String(format: "%.1f GB free", appState.freeStorageGB),
                color: NexusTheme.primary
            )
            quickStatChip(
                icon: "memorychip",
                label: String(format: "%.1f GB RAM", appState.totalRAMGB),
                color: NexusTheme.accent
            )
        }
    }

    private func quickStatChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NexusTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(NexusTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
    }

    // MARK: - Server Connection

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Connect to Nexus", icon: "link", color: NexusTheme.primary)

            @Bindable var state = appState
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .foregroundStyle(NexusTheme.textTertiary)
                    .font(.system(size: 14))

                TextField("https://your-tunnel.trycloudflare.com", text: $state.serverUrl)
                    .textFieldStyle(.plain)
                    .foregroundStyle(NexusTheme.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                if !appState.serverUrl.isEmpty {
                    Button {
                        appState.serverUrl = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(NexusTheme.textTertiary)
                    }
                }
            }
            .padding(12)
            .background(NexusTheme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            Button {
                if appState.connectionState.isConnected {
                    appState.disconnect()
                } else {
                    Task { await appState.connect() }
                }
            } label: {
                HStack(spacing: 8) {
                    if case .connecting = appState.connectionState {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: appState.connectionState.isConnected ? "wifi.slash" : "antenna.radiowaves.left.and.right")
                            .font(.system(size: 14))
                    }
                    Text(appState.connectionState.isConnected ? "Disconnect" : "Connect & Register")
                }
                .nexusPrimaryButton(isEnabled: !appState.serverUrl.isEmpty || appState.connectionState.isConnected)
            }
            .disabled(appState.serverUrl.isEmpty && !appState.connectionState.isConnected)
        }
        .nexusCard(glow: appState.connectionState.isConnected ? NexusTheme.accent : nil)
    }

    // MARK: - Inference Mode

    private var inferenceModeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Inference Mode", icon: "bolt.fill", color: NexusTheme.warning)

            // Segmented toggle
            HStack(spacing: 0) {
                ForEach(InferenceMode.allCases, id: \.self) { mode in
                    let isSelected = appState.inferenceMode == mode
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            appState.inferenceMode = mode
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode == .onDevice ? "iphone" : "cloud.fill")
                                .font(.system(size: 12))
                            Text(mode.label)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? .white : NexusTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(mode == .onDevice ? NexusTheme.accent : NexusTheme.primary)
                                    .shadow(color: (mode == .onDevice ? NexusTheme.accent : NexusTheme.primary).opacity(0.3), radius: 6, y: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(NexusTheme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text(
                    appState.inferenceMode == .onDevice
                        ? "Run models locally on your device with full privacy."
                        : "Run models on the Nexus server for faster inference."
                )
                .font(.system(size: 12))
            }
            .foregroundStyle(NexusTheme.textTertiary)
        }
        .nexusCard()
    }

    // MARK: - Connection Log (Expandable)

    private var connectionLogSection: some View {
        ExpandableSection(title: "Connection Log", icon: "terminal", iconColor: NexusTheme.accent) {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 3) {
                    if appState.connectionLog.isEmpty {
                        Text("No log entries yet")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(NexusTheme.textTertiary)
                    } else {
                        ForEach(Array(appState.connectionLog.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(NexusTheme.accent.opacity(0.9))
                                .textSelection(.enabled)
                                .id(idx)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .padding(10)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(NexusTheme.accent.opacity(0.1), lineWidth: 1)
            )
        }
    }

    // MARK: - Device Info (Expandable)

    private var deviceInfoSection: some View {
        let device = DeviceInfo.current
        return ExpandableSection(title: "Device Info", icon: "iphone", iconColor: NexusTheme.secondary) {
            VStack(spacing: 0) {
                deviceRow("Device", device.name, icon: "iphone")
                deviceDivider
                deviceRow("Platform", device.platform, icon: "apple.logo")
                deviceDivider
                deviceRow("CPU", "\(device.cpuModel) (\(device.cpuCores) cores)", icon: "cpu")
                deviceDivider
                deviceRow("RAM", "\(device.ramGB) GB", icon: "memorychip")
                deviceDivider
                deviceRow("Storage", "\(device.storageGB) GB", icon: "internaldrive")
            }
            .background(NexusTheme.inputBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var deviceDivider: some View {
        Divider().overlay(Color.white.opacity(0.04))
    }

    private func deviceRow(_ label: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(NexusTheme.textTertiary)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(NexusTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NexusTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
