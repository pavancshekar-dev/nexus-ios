import SwiftUI

struct MetricsView: View {
    @Environment(AppState.self) private var appState
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    gaugesSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)

                    liveStatsBar
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 15)

                    inferenceStatsCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 15)

                    engineInfoSection

                    sessionSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(NexusTheme.background)
            .navigationTitle("Metrics")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Circular Gauges

    private var gaugesSection: some View {
        let metrics = appState.metricsReporter.latestMetrics

        return HStack(spacing: 16) {
            CircularGauge(
                value: Double(metrics.cpuUsage) / 100.0,
                color: colorForUsage(metrics.cpuUsage, warn: 75, crit: 90),
                icon: "cpu",
                label: "CPU",
                displayValue: "\(metrics.cpuUsage)%",
                lineWidth: 5
            )
            .frame(maxWidth: .infinity)

            CircularGauge(
                value: Double(metrics.memoryUsage) / 100.0,
                color: colorForUsage(metrics.memoryUsage, warn: 80, crit: 95),
                icon: "memorychip",
                label: "Memory",
                displayValue: "\(metrics.memoryUsage)%",
                lineWidth: 5
            )
            .frame(maxWidth: .infinity)

            CircularGauge(
                value: Double(metrics.temperature) / 80.0,
                color: colorForTemp(metrics.temperature),
                icon: "thermometer.medium",
                label: "Temp",
                displayValue: "\(metrics.temperature)\u{00B0}",
                lineWidth: 5
            )
            .frame(maxWidth: .infinity)

            CircularGauge(
                value: Double(metrics.batteryLevel) / 100.0,
                color: colorForBattery(metrics.batteryLevel),
                icon: batteryIcon(metrics.batteryLevel),
                label: "Battery",
                displayValue: "\(metrics.batteryLevel)%",
                lineWidth: 5
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .nexusGlassCard()
    }

    // MARK: - Live Stats Bar

    private var liveStatsBar: some View {
        HStack(spacing: 0) {
            liveStatItem(
                icon: "bolt.fill",
                value: String(format: "%.1f", appState.metricsReporter.lastTokensPerSec),
                unit: "t/s",
                color: NexusTheme.accent
            )

            verticalDivider

            liveStatItem(
                icon: "number",
                value: formatCompact(appState.metricsReporter.totalTokens),
                unit: "tokens",
                color: NexusTheme.primary
            )

            verticalDivider

            liveStatItem(
                icon: "arrow.triangle.2.circlepath",
                value: "\(appState.metricsReporter.totalInferences)",
                unit: "runs",
                color: NexusTheme.secondary
            )
        }
        .nexusCard()
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: 1, height: 32)
    }

    private func liveStatItem(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(NexusTheme.textPrimary)
                    .contentTransition(.numericText())
            }
            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NexusTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Inference Stats

    private var inferenceStatsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Performance", icon: "gauge.with.dots.needle.bottom.50percent", color: NexusTheme.accent)

            // Speed bar visualization
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Throughput")
                        .font(.system(size: 12))
                        .foregroundStyle(NexusTheme.textSecondary)
                    Spacer()
                    Text(String(format: "%.1f tokens/sec", appState.metricsReporter.lastTokensPerSec))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(NexusTheme.accent)
                }

                GeometryReader { geo in
                    let maxTps: Double = 30.0
                    let pct = min(appState.metricsReporter.lastTokensPerSec / maxTps, 1.0)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(NexusTheme.inputBackground)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(NexusTheme.successGradient)
                            .frame(width: geo.size.width * pct)
                    }
                }
                .frame(height: 8)
            }

            Divider().overlay(Color.white.opacity(0.04))

            HStack(spacing: 20) {
                statColumn(
                    label: "Total Tokens",
                    value: formatNumber(appState.metricsReporter.totalTokens),
                    icon: "number.circle",
                    color: NexusTheme.primary
                )
                statColumn(
                    label: "Inferences",
                    value: "\(appState.metricsReporter.totalInferences)",
                    icon: "arrow.right.circle",
                    color: NexusTheme.secondary
                )
                statColumn(
                    label: "Avg Speed",
                    value: appState.metricsReporter.totalInferences > 0
                        ? String(format: "%.1f", appState.metricsReporter.lastTokensPerSec)
                        : "--",
                    icon: "speedometer",
                    color: NexusTheme.accent
                )
            }
        }
        .nexusCard(glow: NexusTheme.accent)
    }

    private func statColumn(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(NexusTheme.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(NexusTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Engine Info (Expandable)

    private var engineInfoSection: some View {
        ExpandableSection(title: "Engine Details", icon: "gearshape.2", iconColor: NexusTheme.primary) {
            VStack(spacing: 0) {
                engineRow("Mode", appState.inferenceMode.label, icon: "arrow.left.arrow.right")
                engineDivider
                engineRow(
                    "Engine",
                    appState.inferenceMode == .onDevice ? "llama.cpp (Swift)" : "Cloud Inference",
                    icon: "cpu"
                )
                engineDivider
                engineRow("Model", appState.selectedModelName ?? "None", icon: "cube.box")
                engineDivider
                engineRow(
                    "Status",
                    appState.connectionState.isConnected ? "Connected" : "Offline",
                    icon: "circle.fill",
                    valueColor: appState.connectionState.isConnected ? NexusTheme.accent : NexusTheme.textTertiary
                )
                engineDivider
                engineRow(
                    "Context",
                    "8192 tokens",
                    icon: "text.alignleft"
                )
                engineDivider
                engineRow(
                    "Temperature",
                    "0.3",
                    icon: "thermometer.low"
                )
            }
            .background(NexusTheme.inputBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var engineDivider: some View {
        Divider().overlay(Color.white.opacity(0.04))
    }

    private func engineRow(
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

    // MARK: - Session (Expandable)

    private var sessionSection: some View {
        ExpandableSection(title: "Session", icon: "clock", iconColor: NexusTheme.textSecondary) {
            VStack(spacing: 0) {
                engineRow("Device ID", appState.deviceId ?? "N/A", icon: "person.crop.circle")
                engineDivider
                engineRow("Server", appState.serverUrl.isEmpty ? "Not set" : appState.serverUrl, icon: "link")
                engineDivider
                engineRow("Platform", "iOS (SwiftUI)", icon: "apple.logo")
            }
            .background(NexusTheme.inputBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Helpers

    private func colorForUsage(_ value: Int, warn: Int, crit: Int) -> Color {
        if value >= crit { return NexusTheme.error }
        if value >= warn { return NexusTheme.warning }
        return NexusTheme.accent
    }

    private func colorForTemp(_ temp: Int) -> Color {
        if temp >= 60 { return NexusTheme.error }
        if temp >= 50 { return NexusTheme.warning }
        return NexusTheme.accent
    }

    private func colorForBattery(_ level: Int) -> Color {
        if level <= 10 { return NexusTheme.error }
        if level <= 20 { return NexusTheme.warning }
        return NexusTheme.accent
    }

    private func batteryIcon(_ level: Int) -> String {
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        return "battery.25"
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    private func formatCompact(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
