import Foundation
import SwiftUI

@Observable
@MainActor
final class ModelsViewModel {
    var mobileModels: [MobileModel] = []
    var serverModels: [ServerModel] = []
    var isLoading = false
    var errorMessage: String?

    func refresh(appState: AppState) async {
        isLoading = true
        errorMessage = nil

        do {
            switch appState.inferenceMode {
            case .onDevice:
                mobileModels = try await appState.apiClient.fetchMobileModels(
                    serverUrl: appState.serverUrl
                )
                appState.addLog("Loaded \(mobileModels.count) mobile models")
            case .server:
                serverModels = try await appState.apiClient.fetchServerModels(
                    serverUrl: appState.serverUrl
                )
                appState.addLog("Loaded \(serverModels.count) server models")
            }
        } catch {
            errorMessage = error.localizedDescription
            appState.addLog("Model fetch failed: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func downloadModel(_ model: MobileModel, appState: AppState) {
        Task {
            do {
                appState.addLog("Downloading \(model.name)...")
                try await appState.downloadManager.download(
                    model: model,
                    serverUrl: appState.serverUrl
                )
                appState.addLog("Download complete: \(model.name)")
            } catch {
                appState.addLog("Download failed: \(error.localizedDescription)")
            }
        }
    }

    func deleteModel(_ model: MobileModel, appState: AppState) {
        appState.downloadManager.deleteModel(filename: model.file)
        appState.addLog("Deleted \(model.name)")
    }

    func selectMobileModel(_ model: MobileModel, appState: AppState) {
        appState.selectedModelFile = model.file
        appState.selectedModelName = model.name
        appState.selectedModelMethod = model.method

        if appState.inferenceMode == .onDevice {
            // Load into LlamaEngine
            if let path = appState.downloadManager.modelPath(for: model.file) {
                Task {
                    do {
                        try appState.llamaEngine.loadModel(path: path, name: model.name)
                        appState.addLog("Model loaded: \(model.name)")
                    } catch {
                        appState.addLog("Load failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    func selectServerModel(_ model: ServerModel, appState: AppState) {
        appState.selectedModelFile = model.file
        appState.selectedModelName = model.name
        appState.selectedModelMethod = model.method
        appState.addLog("Selected server model: \(model.name)")
    }
}
