import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0

    init() {
        // Style the tab bar
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(NexusTheme.surface)
        appearance.shadowColor = .clear

        // Unselected
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(NexusTheme.textTertiary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(NexusTheme.textTertiary)
        ]

        // Selected
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(NexusTheme.primary)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(NexusTheme.primary)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                ConnectView()
                    .tag(0)
                    .tabItem {
                        Label("Connect", systemImage: selectedTab == 0 ? "link.circle.fill" : "link")
                    }

                ModelsView()
                    .tag(1)
                    .tabItem {
                        Label("Models", systemImage: selectedTab == 1 ? "cpu.fill" : "cpu")
                    }

                ChatView()
                    .tag(2)
                    .tabItem {
                        Label("Chat", systemImage: selectedTab == 2 ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                    }

                MetricsView()
                    .tag(3)
                    .tabItem {
                        Label("Metrics", systemImage: selectedTab == 3 ? "chart.bar.fill" : "chart.bar")
                    }

                SettingsView()
                    .tag(4)
                    .tabItem {
                        Label("Settings", systemImage: selectedTab == 4 ? "gearshape.fill" : "gearshape")
                    }
            }
            .tint(NexusTheme.primary)

            // Top accent line above tab bar
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(NexusTheme.accentGradient)
                    .frame(height: 1)
                    .opacity(0.4)
                    .offset(y: -49) // just above tab bar
            }
            .allowsHitTesting(false)
        }
    }
}
