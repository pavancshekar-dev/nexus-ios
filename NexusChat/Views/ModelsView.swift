import SwiftUI

/// Browse and manage local MLX models + switch inference mode.
struct ModelsView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        NavigationStack {
            List {
                // Inference mode picker
                Section {
                    Picker("Inference Mode", selection: $viewModel.inferenceMode) {
                        ForEach(ChatViewModel.InferenceMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Mode")
                } footer: {
                    Text(viewModel.inferenceMode == .local
                         ? "Run models directly on this device using Apple MLX. No server needed."
                         : "Stream inference from your Nexus server. Requires a connection.")
                }

                // Local models section
                if viewModel.inferenceMode == .local {
                    Section {
                        ForEach(AppModel.allCases) { model in
                            modelRow(model)
                        }
                    } header: {
                        Text("On-Device Models")
                    } footer: {
                        Text("Models are downloaded from HuggingFace on first use and cached locally. 4-bit quantized for efficient on-device inference.")
                    }

                    // Loading state
                    if viewModel.mlxService.isLoading {
                        Section {
                            VStack(spacing: 8) {
                                ProgressView(value: viewModel.mlxService.loadProgress) {
                                    Text("Loading \(viewModel.selectedModel.rawValue)...")
                                        .font(.caption)
                                }
                                Text("\(Int(viewModel.mlxService.loadProgress * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if let error = viewModel.mlxService.errorMessage {
                        Section {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }

                // Info section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("MLX Framework", systemImage: "apple.logo")
                            .font(.subheadline.bold())
                        Text("Apple MLX enables efficient on-device inference using the unified memory architecture of Apple Silicon. Models run on the GPU via Metal with minimal memory overhead.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Models")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func modelRow(_ model: AppModel) -> some View {
        Button {
            viewModel.selectedModel = model
            Task { await viewModel.loadSelectedModel() }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.rawValue)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        if model.supportsVision {
                            Image(systemName: "eye")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                    Text("\(model.huggingFaceID)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("~\(String(format: "%.1f", model.estimatedSizeGB)) GB")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if viewModel.selectedModel == model {
                    if viewModel.isModelLoaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if viewModel.mlxService.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
