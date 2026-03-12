import SwiftUI
import PhotosUI

/// Text input bar with PhotosPicker and send/stop buttons.
struct MessageInputView: View {
    @Binding var text: String
    @Binding var imageData: Data?
    let isGenerating: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 8) {
            // Image preview
            if let data = imageData, let uiImage = UIImage(data: data) {
                HStack {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            imageData = nil
                            selectedItem = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .background(Circle().fill(.black.opacity(0.5)))
                        }
                        .offset(x: 4, y: -4)
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }

            HStack(alignment: .bottom, spacing: 8) {
                // Photo picker
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images
                ) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            if let uiImage = UIImage(data: data),
                               let jpeg = uiImage.jpegData(compressionQuality: 0.5) {
                                imageData = jpeg
                            }
                        }
                    }
                }

                // Text field
                TextField("Message...", text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .onSubmit { if !isGenerating { onSend() } }

                // Send / Stop button
                if isGenerating {
                    Button(action: onStop) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                } else {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                             ? .gray : .accentColor)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && imageData == nil)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}
