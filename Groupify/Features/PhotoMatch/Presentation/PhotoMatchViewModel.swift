import AVFoundation
import Combine
import Photos
import UIKit

// MARK: - UI Models

struct MatchUiModel: Identifiable {
    let id = UUID()
    let assetIdentifier: String
    let scorePercent: Int
}

struct QueryFaceUiModel: Identifiable {
    let id: Int
    let label: String
    let boundingBox: FaceBoundingBox
    var isSelected: Bool
    var thumbnail: UIImage?
}

// MARK: - UI State

struct PhotoMatchUiState {
    // Photo picking
    var selectedImage: UIImage?
    var isPicking: Bool = false
    var isTakingPhoto: Bool = false

    // Messages
    var userMessage: String?
    var showSettingsAction: Bool = false

    // Query face chips
    var queryFaces: [QueryFaceUiModel] = []
    var focusedFaceId: Int?
    var isFaceLoading: Bool = false

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

    // Debug
    #if DEBUG
    var debugEmbedderName: String = ""
    #endif

    // Derived
    var hasPhoto: Bool { selectedImage != nil }
    var isCameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
    var isBusy: Bool { isIndexing || isSearching || isFaceLoading }

    var selectedFaces: [QueryFaceUiModel] {
        queryFaces.filter(\.isSelected)
    }

    var hasSelectedFaces: Bool { !selectedFaces.isEmpty }

    var focusedBoundingBox: FaceBoundingBox? {
        guard let fid = focusedFaceId else { return nil }
        return queryFaces.first { $0.id == fid }?.boundingBox
    }

    var filteredMatches: [MatchUiModel] {
        allMatches.filter { Double($0.scorePercent) / 100.0 >= matchSensitivity }
    }
}

// MARK: - ViewModel

final class PhotoMatchViewModel: ObservableObject {
    @Published var state = PhotoMatchUiState()

    private let indexUseCase: IndexLibraryUseCase
    private let searchUseCase: SearchByPhotoUseCase
    private let detectQueryFacesUseCase: DetectQueryFacesUseCase
    private let repository: any FaceIndexRepository
    private let photoService: any PhotoLibraryService

    /// Monotonically increasing token to cancel stale face-detection tasks.
    private var faceDetectionToken: Int = 0

    init() {
        let detector = VisionFaceDetector()
        let embedderResult = FaceEmbedderFactory.make()
        let embedder = embedderResult.embedder
        let repo = FileFaceIndexRepository()
        let photoSvc = PhotoKitLibraryService()

        self.repository = repo
        self.photoService = photoSvc
        self.detectQueryFacesUseCase = DetectQueryFacesUseCase(detector: detector)
        self.indexUseCase = IndexLibraryUseCase(
            photoService: photoSvc,
            detector: detector,
            embedder: embedder,
            repository: repo
        )
        self.searchUseCase = SearchByPhotoUseCase(
            embedder: embedder,
            repository: repo
        )

        // Show warning if we fell back to the stub embedder.
        if let warning = embedderResult.warningMessage {
            state.userMessage = warning
        }

        #if DEBUG
        state.debugEmbedderName = embedderResult.embedderName
        #endif
    }

    // MARK: - Photo Picking

    func onTapPickPhoto() {
        state.isPicking = true
    }

    func onPickedPhoto(image: UIImage) {
        applyNewQueryImage(image)
        state.isPicking = false
    }

    func onPickCancelled() {
        state.isPicking = false
    }

    // MARK: - Camera

    func onTapTakePhoto() {
        guard state.isCameraAvailable else {
            state.userMessage = L10n.cameraNotAvailable
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
                        self.state.userMessage = L10n.cameraPermissionDenied
                        self.state.showSettingsAction = true
                    }
                }
            }

        case .denied, .restricted:
            state.userMessage = L10n.cameraPermissionDenied
            state.showSettingsAction = true

        @unknown default:
            state.userMessage = L10n.unableToAccessCamera
        }
    }

    func onCameraPicked(image: UIImage) {
        applyNewQueryImage(image)
        state.isTakingPhoto = false
    }

    func onCameraCancelled() {
        state.isTakingPhoto = false
    }

    // MARK: - Settings

    func onOpenSettingsTapped() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Query Image & Face Detection

    /// Called whenever a new query image is set (gallery or camera).
    private func applyNewQueryImage(_ image: UIImage) {
        state.selectedImage = image
        state.queryFaces = []
        state.focusedFaceId = nil
        state.allMatches = []
        state.matches = []
        clearMessage()

        faceDetectionToken += 1
        let token = faceDetectionToken

        Task {
            state.isFaceLoading = true
            defer {
                if faceDetectionToken == token {
                    state.isFaceLoading = false
                }
            }

            // Use a simple identifier from the image pointer for stable IDs.
            let imageId = "\(ObjectIdentifier(image).hashValue)"

            do {
                let faces = try await detectQueryFacesUseCase.execute(
                    queryImage: image, imageIdentifier: imageId
                )

                // Check this result is still relevant.
                guard faceDetectionToken == token else { return }

                // Build UI models with cropped thumbnails.
                let uiModels: [QueryFaceUiModel] = faces.enumerated().map { index, face in
                    let thumb = FaceCropper.crop(from: image, boundingBox: face.boundingBox)
                        .flatMap { UIImage(cgImage: $0) }
                    return QueryFaceUiModel(
                        id: face.id,
                        label: L10n.faceLabel(index + 1),
                        boundingBox: face.boundingBox,
                        isSelected: index == 0, // Select largest by default
                        thumbnail: thumb
                    )
                }

                state.queryFaces = uiModels
                state.focusedFaceId = uiModels.first?.id
            } catch {
                guard faceDetectionToken == token else { return }
                state.userMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Face Chip Interactions

    func onToggleFace(id: Int) {
        guard let idx = state.queryFaces.firstIndex(where: { $0.id == id }) else { return }
        state.queryFaces[idx].isSelected.toggle()
        state.focusedFaceId = id
    }

    func onSelectAllFaces() {
        for i in state.queryFaces.indices {
            state.queryFaces[i].isSelected = true
        }
        state.focusedFaceId = state.queryFaces.first?.id
    }

    func onClearFaceSelection() {
        for i in state.queryFaces.indices {
            state.queryFaces[i].isSelected = false
        }
    }

    // MARK: - Detection Pipeline

    func onTapStartDetection() {
        guard state.hasPhoto, !state.isBusy else { return }

        guard state.hasSelectedFaces else {
            state.userMessage = L10n.selectAtLeastOneFace
            state.showSettingsAction = false
            return
        }

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
                    state.userMessage = L10n.photoLibraryAccessRequired
                    state.showSettingsAction = true
                }
            case .denied, .restricted:
                state.userMessage = L10n.photoLibraryAccessDenied
                state.showSettingsAction = true
            @unknown default:
                state.userMessage = L10n.unableToAccessPhotoLibrary
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
        state.indexingStatus = L10n.indexPreparing
        defer { state.isIndexing = false }

        do {
            _ = try await indexUseCase.execute { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.state.indexingProgress = progress.fraction
                    self?.state.indexingStatus = progress.status
                }
            }
        } catch {
            state.userMessage = L10n.indexingFailed(error.localizedDescription)
        }
    }

    private func runSearch() async {
        guard let queryImage = state.selectedImage else { return }
        let selectedBoxes = state.selectedFaces.map(\.boundingBox)
        guard !selectedBoxes.isEmpty else { return }

        state.isSearching = true
        defer { state.isSearching = false }

        do {
            let results = try await searchUseCase.execute(
                queryImage: queryImage,
                selectedFaces: selectedBoxes
            )
            let models = results.map {
                MatchUiModel(
                    assetIdentifier: $0.assetIdentifier,
                    scorePercent: Int($0.similarityScore * 100)
                )
            }
            state.allMatches = models
            state.matches = state.filteredMatches
            if state.matches.isEmpty {
                state.userMessage = L10n.noSimilarFacesFound
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
                state.userMessage = L10n.couldNotExportImages
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
