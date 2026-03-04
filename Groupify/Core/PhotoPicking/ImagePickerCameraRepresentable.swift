import AVFoundation
import SwiftUI
import UIKit

/// Wraps UIImagePickerController with `.camera` source type for SwiftUI.
struct ImagePickerCameraRepresentable: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void
    let onCancelled: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, onCancelled: onCancelled)
    }

    /// Minimum pixel dimension to accept — anything smaller is likely a
    /// black frame produced when camera permission was denied.
    private static let minimumImageDimension: CGFloat = 10

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onPicked: (UIImage) -> Void
        let onCancelled: () -> Void

        init(onPicked: @escaping (UIImage) -> Void, onCancelled: @escaping () -> Void) {
            self.onPicked = onPicked
            self.onCancelled = onCancelled
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)

            // Safety: reject if camera permission was revoked mid-session.
            guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
                onCancelled()
                return
            }

            guard let image = info[.originalImage] as? UIImage,
                  image.size.width >= ImagePickerCameraRepresentable.minimumImageDimension,
                  image.size.height >= ImagePickerCameraRepresentable.minimumImageDimension else {
                onCancelled()
                return
            }

            onPicked(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onCancelled()
        }
    }
}
