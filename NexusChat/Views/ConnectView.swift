import SwiftUI

/// Server connection UI: URL and status.
struct ConnectView: View {
    @State private var viewModel: ConnectionViewModel

    init(apiService: NexusAPIService) {
        _viewModel = State(initialValue: ConnectionViewModel(apiService: apiService))
    }

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.isConnected {
                    connectedSection
                } else {
                    connectionFormSection
                }

                statusSection
            }
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Connected State

    private var connectedSection: some View {
        Section {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading) {
                    Text("Connected")
                        .font(.headline)
                    if let deviceId = viewModel.deviceId {
                        Text("Device: \(deviceId)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            Button("Disconnect", role: .destructive) {
                viewModel.disconnect()
            }
        } header: {
            Text("Server Connection")
        }
    }

    // MARK: - Connection Form

    private var connectionFormSection: some View {
        Section {
            TextField("Server URL", text: $viewModel.serverURL)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button {
                Task { await viewModel.connect() }
            } label: {
                HStack {
                    if viewModel.isConnecting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.isConnecting ? "Connecting..." : "Connect & Register")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.isConnecting)
        } header: {
            Text("Nexus Server")
        } footer: {
            Text("Enter the URL of your Nexus server (e.g., https://nexus.example.com). Credentials are handled automatically.")
        }
    }

    // MARK: - Status Messages

    @ViewBuilder
    private var statusSection: some View {
        if let error = viewModel.errorMessage {
            Section {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }

        if let success = viewModel.successMessage {
            Section {
                Label(success, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }

        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("About Server Mode")
                    .font(.subheadline.bold())
                Text("Connect to your Nexus server for cloud-powered inference using any quantized model. Server mode streams responses via SSE for real-time token display.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
