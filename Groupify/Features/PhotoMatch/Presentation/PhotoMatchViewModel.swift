import AVFoundation
import Combine
import UIKit

// MARK: - UI State

struct PhotoMatchUiState {
    var selectedImage: UIImage?
    var isPicking: Bool = false
    var isTakingPhoto: Bool = false
    var userMessage: String?
    var showSettingsAction: Bool = false

    var hasPhoto: Bool { selectedImage != nil }
    var isCameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
}

// MARK: - ViewModel

final class PhotoMatchViewModel: ObservableObject {
    @Published var state = PhotoMatchUiState()

    // MARK: - Intents

    func onTapPickPhoto() {
        state.isTakingPhoto = false
           state.userMessage = nil
           state.showSettingsAction = false
        state.isPicking = true
    }

    func onPickedPhoto(image: UIImage) {
        state.selectedImage = image
        state.isPicking = false
        state.isTakingPhoto = false
            state.userMessage = nil
            state.showSettingsAction = false
    }

    func onPickCancelled() {
        state.isPicking = false
    }

    func onTapTakePhoto() {
        state.isPicking = false
        state.userMessage = nil
        state.showSettingsAction = false

           guard state.isCameraAvailable else {
               state.userMessage = "Camera not available on this device"
               return
           }
        guard state.isCameraAvailable else {
            state.userMessage = "Camera not available on this device"
            state.showSettingsAction = false
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            state.isTakingPhoto = true

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.state.isTakingPhoto = true
                    } else {
                        self.state.userMessage = "Camera permission denied. Enable it in Settings."
                        self.state.showSettingsAction = true
                    }
                }
            }

        case .denied, .restricted:
            state.userMessage = "Camera permission denied. Enable it in Settings."
            state.showSettingsAction = true

        @unknown default:
            state.userMessage = "Unable to access camera"
            state.showSettingsAction = false
        }
    }

    func onCameraPicked(image: UIImage) {
        state.selectedImage = image
        state.isTakingPhoto = false
        state.userMessage = nil
        state.showSettingsAction = false
        state.isPicking = false
    }

    func onCameraCancelled() {
        state.isTakingPhoto = false
    }

    func onOpenSettingsTapped() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func onTapStartDetection() {
        guard state.hasPhoto else { return }
        state.userMessage = "Detection not implemented yet"
        state.showSettingsAction = false
    }

    func onDismissMessage() {
        state.userMessage = nil
        state.showSettingsAction = false
    }
}
