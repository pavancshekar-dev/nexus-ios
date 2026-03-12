import SwiftUI

enum NexusTheme {
    // MARK: - Colors
    static let background = Color(hex: 0x080A12)
    static let surface = Color(hex: 0x0C0E1A)
    static let surfaceLight = Color(hex: 0x111827)
    static let inputBackground = Color(hex: 0x121522)
    static let elevated = Color(hex: 0x1A1D2E)

    static let primary = Color(hex: 0x7B9FC7)
    static let primaryDark = Color(hex: 0x5A7EA6)
    static let secondary = Color(hex: 0xD63384)
    static let accent = Color(hex: 0x34D399)
    static let accentDark = Color(hex: 0x10B981)

    static let textPrimary = Color(hex: 0xF0F0F5)
    static let textSecondary = Color(hex: 0x8B8B9E)
    static let textTertiary = Color(hex: 0x6B6B7E)

    static let warning = Color(hex: 0xFBBF24)
    static let error = Color(hex: 0xF87171)

    // MARK: - Gradients
    static let titleGradient = LinearGradient(
        colors: [.white, primary, secondary],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let accentGradient = LinearGradient(
        colors: [primary, secondary],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cardGradient = LinearGradient(
        colors: [surface, Color(hex: 0x0F1225)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let glowGradient = LinearGradient(
        colors: [primary.opacity(0.3), secondary.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let successGradient = LinearGradient(
        colors: [accent, Color(hex: 0x06B6D4)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let errorGradient = LinearGradient(
        colors: [error, Color(hex: 0xEF4444)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Color Extension

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Card Modifiers

struct NexusCardModifier: ViewModifier {
    var glowColor: Color? = nil

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(NexusTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.08),
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: (glowColor ?? .clear).opacity(0.15), radius: 12, y: 4)
            }
    }
}

struct NexusGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.12),
                                        Color.white.opacity(0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 16, y: 8)
            }
    }
}

struct NexusPrimaryButtonModifier: ViewModifier {
    var isEnabled: Bool = true

    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? NexusTheme.primary : NexusTheme.textTertiary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(isEnabled ? 0.15 : 0), lineWidth: 1)
                    )
                    .shadow(color: (isEnabled ? NexusTheme.primary : .clear).opacity(0.3), radius: 8, y: 4)
            }
    }
}

struct NexusBadgeModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.2), lineWidth: 0.5)
            )
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String
    var color: Color = NexusTheme.textPrimary

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NexusTheme.textPrimary)
        }
    }
}

// MARK: - Expandable Section

struct ExpandableSection<Content: View>: View {
    let title: String
    let icon: String
    var iconColor: Color = NexusTheme.primary
    @ViewBuilder let content: () -> Content
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    SectionHeader(title: title, icon: icon, color: iconColor)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NexusTheme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                        .overlay(Color.white.opacity(0.06))
                        .padding(.vertical, 4)

                    content()
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .nexusCard()
    }
}

// MARK: - Pulsing Dot

struct PulsingDot: View {
    let color: Color
    let isActive: Bool

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .scaleEffect(isPulsing ? 1.3 : 0.8)
                    .opacity(isPulsing ? 0 : 0.6)
            }
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            if isActive {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.08),
                        .clear
                    ],
                    startPoint: .init(x: phase - 0.5, y: 0.5),
                    endPoint: .init(x: phase + 0.5, y: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            )
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

// MARK: - Circular Gauge

struct CircularGauge: View {
    let value: Double // 0...1
    let color: Color
    let icon: String
    let label: String
    let displayValue: String
    var lineWidth: CGFloat = 6

    @State private var animatedValue: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Track
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: lineWidth)

                // Progress
                Circle()
                    .trim(from: 0, to: animatedValue)
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.6), color],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * animatedValue)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(color)
                    Text(displayValue)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(NexusTheme.textPrimary)
                }
            }
            .frame(width: 72, height: 72)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NexusTheme.textSecondary)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animatedValue = newValue
            }
        }
    }
}

// MARK: - Animated Counter

struct AnimatedCounter: View {
    let value: Double
    let format: String
    var color: Color = NexusTheme.primary

    @State private var displayValue: Double = 0

    var body: some View {
        Text(String(format: format, displayValue))
            .onAppear { displayValue = value }
            .onChange(of: value) { _, newValue in
                withAnimation(.spring(response: 0.5)) {
                    displayValue = newValue
                }
            }
            .contentTransition(.numericText(value: displayValue))
            .foregroundStyle(color)
    }
}

// MARK: - View Extensions

extension View {
    func nexusCard(glow glowColor: Color? = nil) -> some View {
        modifier(NexusCardModifier(glowColor: glowColor))
    }

    func nexusGlassCard() -> some View {
        modifier(NexusGlassCardModifier())
    }

    func nexusPrimaryButton(isEnabled: Bool = true) -> some View {
        modifier(NexusPrimaryButtonModifier(isEnabled: isEnabled))
    }

    func nexusBadge(color: Color) -> some View {
        modifier(NexusBadgeModifier(color: color))
    }

    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    func staggeredAppear(index: Int) -> some View {
        self
            .opacity(1)
            .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.06), value: true)
    }
}
