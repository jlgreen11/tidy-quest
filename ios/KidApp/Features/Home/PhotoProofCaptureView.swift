import SwiftUI
import UIKit
import TidyQuestCore

// MARK: - PhotoProofCaptureView

/// Sheet shown when a chore requires photo proof.
/// Wraps UIImagePickerController for camera access (iOS 17 — camera still requires UIImagePickerController or AVFoundation).
/// Shows a content reminder banner, camera preview, and Retake/Use buttons.
struct PhotoProofCaptureView: View {
    let instance: ChoreInstance
    let template: ChoreTemplate
    /// Called with the proof photo UUID once upload succeeds. Parent closes the sheet.
    let onPhotoUploaded: (UUID) -> Void
    @Binding var isPresented: Bool

    @State private var capturedImage: UIImage?
    @State private var showCamera = true
    @State private var isUploading = false
    @State private var uploadError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = capturedImage {
                    previewScreen(image: image)
                } else if showCamera {
                    ImagePickerRepresentable(image: $capturedImage)
                        .ignoresSafeArea()
                } else {
                    // Should not reach — but handle gracefully
                    ContentUnavailableView(
                        "Camera unavailable",
                        systemImage: "camera.slash",
                        description: Text("Please allow camera access in Settings.")
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Preview screen

    private func previewScreen(image: UIImage) -> some View {
        VStack(spacing: 0) {
            // Content reminder banner
            HStack(spacing: 8) {
                Image(systemName: "eye.slash.fill")
                    .foregroundStyle(.orange)
                Text("Only photos of what you did — no people, no faces.")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.black.opacity(0.7))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Photo reminder: Only photos of what you did. No people, no faces.")

            // Image preview
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Upload error
            if let error = uploadError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.vertical, 4)
            }

            // Action buttons
            HStack(spacing: 24) {
                Button {
                    capturedImage = nil
                    showCamera = true
                    uploadError = nil
                } label: {
                    Label("Retake", systemImage: "arrow.counterclockwise")
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.15), in: Capsule())
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Retake photo")

                Button {
                    Task { await uploadPhoto(image) }
                } label: {
                    if isUploading {
                        ProgressView()
                            .tint(.black)
                            .padding(.horizontal, 36)
                            .padding(.vertical, 12)
                            .background(.white, in: Capsule())
                    } else {
                        Label("Use Photo", systemImage: "checkmark")
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(.white, in: Capsule())
                            .foregroundStyle(.black)
                    }
                }
                .disabled(isUploading)
                .accessibilityLabel(isUploading ? "Uploading photo" : "Use this photo")
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 24)
            .background(Color.black)
        }
    }

    // MARK: - Upload

    private func uploadPhoto(_ image: UIImage) async {
        isUploading = true
        uploadError = nil
        defer { isUploading = false }

        // Simulate upload — real implementation calls APIClient upload endpoint
        // which returns a proof_photo_id UUID, then calls completeChoreInstance.
        // The API client handles the multipart upload internally.
        do {
            try await Task.sleep(for: .milliseconds(800))  // Simulated upload delay
            let photoId = UUID()
            onPhotoUploaded(photoId)
            isPresented = false
        } catch {
            uploadError = "Upload failed. Try again."
        }
    }
}

// MARK: - ImagePickerRepresentable

/// UIViewControllerRepresentable wrapping UIImagePickerController for camera access.
struct ImagePickerRepresentable: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator { Coordinator(image: $image) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        // Hide default controls — we provide our own Retake/Use buttons
        picker.showsCameraControls = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        @Binding var image: UIImage?

        init(image: Binding<UIImage?>) { self._image = image }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            image = info[.originalImage] as? UIImage
        }
    }
}

// MARK: - Preview
#Preview("PhotoProofCaptureView") {
    let templates = MockAPIClient.seedTemplates
    let template = templates.first(where: { $0.requiresPhoto }) ?? templates[0]
    let today = ISO8601DateFormatter().string(from: Date()).prefix(10).description
    let instance = ChoreInstance(
        id: UUID(), templateId: template.id, userId: UUID(),
        scheduledFor: today, windowStart: nil, windowEnd: nil,
        status: .pending, completedAt: nil, approvedAt: nil,
        proofPhotoId: nil, awardedPoints: nil,
        completedByDevice: nil, completedAsUser: nil, createdAt: Date()
    )
    return PhotoProofCaptureView(
        instance: instance,
        template: template,
        onPhotoUploaded: { _ in },
        isPresented: .constant(true)
    )
}
