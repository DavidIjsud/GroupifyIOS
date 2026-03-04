import AVFoundation
import Combine
import Photos
import UIKit

// MARK: - UI State

struct MatchUiModel: Identifiable {
    let id = UUID()
    let assetIdentifier: String
    let scorePercent: Int
}

struct PhotoMatchUiState {
    // Photo picking
    var selectedImage: UIImage?
    var isPicking: Bool = false
    var isTakingPhoto: Bool = false

    // Messages
    var userMessage: String?
    var showSettingsAction: Bool = false

    // Indexing
    var isIndexing: Bool = false
    var indexingProgress: Float = 0
    var indexingStatus: String = ""

    // Search
    var isSearching: Bool = false
    var matchSensitivity: Double = 0.82
    var allMatches: [MatchUiModel] = []
    var matches: [MatchUiModel] = []

    // Sharing
    var showShareSheet: Bool = false
    var shareURLs: [URL] = []

    // Derived
    var hasPhoto: Bool { selectedImage != nil }
    var isCameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
    var isBusy: Bool { isIndexing || isSearching }

    var filteredMatches: [MatchUiModel] {
        allMatches.filter { Double($0.scorePercent) / 100.0 >= matchSensitivity }
    }
}

// MARK: - ViewModel

final class PhotoMatchViewModel: ObservableObject {
    @Published var state = PhotoMatchUiState()

    private let indexUseCase: IndexLibraryUseCase
    private let searchUseCase: SearchByPhotoUseCase
    private let repository: any FaceIndexRepository
    private let photoService: any PhotoLibraryService

    init() {
        let detector = VisionFaceDetector()
        let embedder = StubFaceEmbedder()
        let repo = FileFaceIndexRepository()
        let photoSvc = PhotoKitLibraryService()

        self.repository = repo
        self.photoService = photoSvc
        self.indexUseCase = IndexLibraryUseCase(
            photoService: photoSvc,
            detector: detector,
            embedder: embedder,
            repository: repo
        )
        self.searchUseCase = SearchByPhotoUseCase(
            detector: detector,
            embedder: embedder,
            repository: repo
        )
    }

    // MARK: - Photo Picking

    func onTapPickPhoto() {
        state.isPicking = true
    }

    func onPickedPhoto(image: UIImage) {
        state.selectedImage = image
        state.isPicking = false
        clearMessage()
    }

    func onPickCancelled() {
        state.isPicking = false
    }

    // MARK: - Camera

    func onTapTakePhoto() {
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
        }
    }

    func onCameraPicked(image: UIImage) {
        state.selectedImage = image
        state.isTakingPhoto = false
        clearMessage()
    }

    func onCameraCancelled() {
        state.isTakingPhoto = false
    }

    // MARK: - Settings

    func onOpenSettingsTapped() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Detection Pipeline

    func onTapStartDetection() {
        guard state.hasPhoto, !state.isBusy else { return }

        Task {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            switch status {
            case .authorized, .limited:
                await runPipeline()
            case .notDetermined:
                let granted = await photoService.requestAuthorization()
                if granted == .authorized || granted == .limited {
                    await runPipeline()
                } else {
                    state.userMessage = "Photo library access is required to search your photos."
                    state.showSettingsAction = true
                }
            case .denied, .restricted:
                state.userMessage = "Photo library access denied. Enable it in Settings."
                state.showSettingsAction = true
            @unknown default:
                state.userMessage = "Unable to access photo library."
            }
        }
    }

    private func runPipeline() async {
        let existing = (try? await repository.load()) ?? []
        if existing.isEmpty {
            await runIndexing()
        }
        await runSearch()
    }

    private func runIndexing() async {
        state.isIndexing = true
        state.indexingProgress = 0
        state.indexingStatus = "Preparing…"
        defer { state.isIndexing = false }

        do {
            _ = try await indexUseCase.execute { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.state.indexingProgress = progress.fraction
                    self?.state.indexingStatus = progress.status
                }
            }
        } catch {
            state.userMessage = "Indexing failed: \(error.localizedDescription)"
        }
    }

    private func runSearch() async {
        guard let queryImage = state.selectedImage else { return }
        state.isSearching = true
        defer { state.isSearching = false }

        do {
            let results = try await searchUseCase.execute(queryImage: queryImage)
            let models = results.map {
                MatchUiModel(
                    assetIdentifier: $0.assetIdentifier,
                    scorePercent: Int($0.similarityScore * 100)
                )
            }
            state.allMatches = models
            state.matches = state.filteredMatches
            if state.matches.isEmpty {
                state.userMessage = "No similar faces found. Try lowering the sensitivity."
            }
        } catch {
            state.userMessage = error.localizedDescription
        }
    }

    // MARK: - Sensitivity

    func onSensitivityChanged(value: Double) {
        state.matchSensitivity = value
        state.matches = state.filteredMatches
    }

    // MARK: - Sharing

    func onShareMatches() {
        guard !state.matches.isEmpty else { return }
        Task {
            state.isSearching = true
            defer { state.isSearching = false }
            let ids = Array(state.matches.prefix(25).map(\.assetIdentifier))
            do {
                let urls = try await photoService.exportForSharing(assetIdentifiers: ids)
                state.shareURLs = urls
                state.showShareSheet = true
            } catch {
                state.userMessage = "Could not export images for sharing."
            }
        }
    }

    func onDismissShareSheet() {
        state.showShareSheet = false
        state.shareURLs = []
    }

    // MARK: - Messages

    func onDismissMessage() {
        clearMessage()
    }

    private func clearMessage() {
        state.userMessage = nil
        state.showSettingsAction = false
    }
}
