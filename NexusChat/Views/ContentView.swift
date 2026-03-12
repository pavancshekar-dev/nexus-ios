import SwiftUI

/// Root tab view: Chat, Models, Connect, Settings.
struct ContentView: View {
    @State private var viewModel = ChatViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Chat", systemImage: "message.fill") {
                ChatView(viewModel: viewModel)
            }

            Tab("Models", systemImage: "cpu") {
                ModelsView(viewModel: viewModel)
            }

            Tab("Connect", systemImage: "antenna.radiowaves.left.and.right") {
                ConnectView(apiService: viewModel.apiService)
            }
        }
        .tint(.accentColor)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                viewModel.releaseModel()
            case .active:
                if !viewModel.isModelLoaded && viewModel.inferenceMode == .local {
                    Task { await viewModel.loadSelectedModel() }
                }
            default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
}
