import Combine
import UIKit

// MARK: - UI State

struct PhotoMatchUiState {
    var selectedImage: UIImage?
    var isPicking: Bool = false
    var isTakingPhoto: Bool = false
    var userMessage: String?

    var hasPhoto: Bool { selectedImage != nil }
    var isCameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
}

// MARK: - ViewModel

final class PhotoMatchViewModel: ObservableObject {
    @Published var state = PhotoMatchUiState()

    // MARK: - Intents

    func onTapPickPhoto() {
        state.isPicking = true
    }

    func onPickedPhoto(image: UIImage) {
        state.selectedImage = image
        state.isPicking = false
    }

    func onPickCancelled() {
        state.isPicking = false
    }

    func onTapTakePhoto() {
        guard state.isCameraAvailable else {
            state.userMessage = "Camera not available on this device"
            return
        }
        state.isTakingPhoto = true
    }

    func onCameraPicked(image: UIImage) {
        state.selectedImage = image
        state.isTakingPhoto = false
    }

    func onCameraCancelled() {
        state.isTakingPhoto = false
    }

    func onTapStartDetection() {
        guard state.hasPhoto else { return }
        state.userMessage = "Detection not implemented yet"
    }

    func onDismissMessage() {
        state.userMessage = nil
    }
}
