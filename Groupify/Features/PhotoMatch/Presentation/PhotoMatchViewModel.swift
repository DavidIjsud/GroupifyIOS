import Combine
import UIKit

// MARK: - UI State

struct PhotoMatchUiState {
    var selectedImage: UIImage?
    var isPicking: Bool = false
    var userMessage: String?

    var hasPhoto: Bool { selectedImage != nil }
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
        state.userMessage = "Camera not implemented yet"
    }

    func onTapStartDetection() {
        guard state.hasPhoto else { return }
        state.userMessage = "Detection not implemented yet"
    }

    func onDismissMessage() {
        state.userMessage = nil
    }
}
