import AVFoundation
import Combine
import Photos
import SwiftUI

// MARK: - Permission Warning Level

enum PhotoPermissionWarning {
    case none
    case limited
    case denied
}

// MARK: - Search Mode

/// Whether the Home screen searches by an uploaded face photo, by typed text
/// (OCR), or by a free-text scene description (CLIP).
enum SearchMode {
    case faces
    case text
    case scene
}

// MARK: - UI Models

struct MatchUiModel: Identifiable {
    let id = UUID()
    let assetIdentifier: String
    let scorePercent: Int
    var isSelected: Bool = false
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
    // Search mode (face photo vs. typed text vs. scene description)
    var searchMode: SearchMode = .faces
    var searchText: String = ""
    /// Kept separate from `searchText` so the OCR and scene text fields don't
    /// clobber each other when switching modes.
    var sceneDescription: String = ""

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
    var matchSensitivity: Float = 0.40
    /// CLIP text↔image scores run lower than face↔face, so the scene threshold is
    /// independent and tuned lower. (Tune on-device.)
    var sceneSensitivity: Float = 0.20
    var allMatches: [MatchUiModel] = []
    var matches: [MatchUiModel] = []
    var visibleMatchCount: Int = 0
    var hasMoreMatches: Bool = false

    /// When on, tapping a result toggles its selection (iOS-style "Select" mode).
    /// When off, the grid is read-only and Save/Share act on all matches.
    var isSelectionMode: Bool = false

    /// Asset shown in the full-screen preview (when select mode is off and the
    /// user taps a result). `nil` means no preview is presented.
    var previewAssetIdentifier: String?

    // Sharing
    var showShareSheet: Bool = false
    var shareURLs: [URL] = []

    // Permission dialogs
    var showPrePermissionDialog: Bool = false
    var showLimitedAccessDialog: Bool = false
    var showDeniedAccessDialog: Bool = false

    // Permission warning card
    var permissionWarning: PhotoPermissionWarning = .none
    var isWarningCardDismissed: Bool = false

    // Derived
    var hasPhoto: Bool { selectedImage != nil }
    var hasSearchText: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var hasSceneDescription: Bool {
        !sceneDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
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

    var selectedMatches: [MatchUiModel] {
        matches.filter(\.isSelected)
    }

    var hasSelectedMatches: Bool { !selectedMatches.isEmpty }

    var shouldShowWarningCard: Bool {
        permissionWarning != .none && !isWarningCardDismissed
    }
}

// MARK: - ViewModel

final class PhotoMatchViewModel: ObservableObject {
    @Published var state = PhotoMatchUiState()
    @Published private(set) var showAds: Bool = true

    private let indexUseCase: IndexLibraryUseCase
    private let searchUseCase: SearchByPhotoUseCase
    private let detectQueryFacesUseCase: DetectQueryFacesUseCase
    private let indexTextUseCase: IndexLibraryTextUseCase
    private let searchTextUseCase: SearchByTextUseCase
    private let indexSceneUseCase: IndexLibrarySceneUseCase
    private let searchSceneUseCase: SearchBySceneUseCase
    private let repository: any FaceIndexRepository
    private let textRepository: any TextIndexRepository
    private let sceneRepository: any SceneIndexRepository
    /// The vector space the scene index should be in (e.g. "mobileclip_s2" or
    /// "stub"). If the stored index was built by a different model, it's rebuilt.
    private let sceneModelId: String
    private let photoService: any PhotoLibraryService
    private let metadataStore = IndexMetadataStore()
    private let rewardedAdManager = RewardedAdManager(
        adUnitID: "ca-app-pub-2389567920636267/2610360855"
    )
    private var configCancellable: AnyCancellable?

    /// How many times the user has tapped "Start Detection" this session.
    private var detectionCount: Int = 0

    /// How many times the user has tapped "Share Matches" this session.
    private var shareCount: Int = 0

    /// Show a rewarded ad every N-th action, after the first free runs.
    private static let adFrequency = 3
    private static let freeRuns = 2

    /// Monotonically increasing token to cancel stale face-detection tasks.
    private var faceDetectionToken: Int = 0

    init() {
        let detector = VisionFaceDetector()
        let embedderResult = FaceEmbedderFactory.make()
        let embedder = embedderResult.embedder
        let repo = FileFaceIndexRepository()
        let photoSvc = PhotoKitLibraryService()
        let textRecognizer = VisionTextRecognizer()
        let textRepo = FileTextIndexRepository()
        let sceneEmbedderResult = SceneEmbedderFactory.make()
        let sceneEmbedder = sceneEmbedderResult.embedder
        let sceneRepo = FileSceneIndexRepository()

        self.repository = repo
        self.textRepository = textRepo
        self.sceneRepository = sceneRepo
        self.sceneModelId = sceneEmbedderResult.modelId
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
        self.indexTextUseCase = IndexLibraryTextUseCase(
            photoService: photoSvc,
            recognizer: textRecognizer,
            repository: textRepo
        )
        self.searchTextUseCase = SearchByTextUseCase(repository: textRepo)
        self.indexSceneUseCase = IndexLibrarySceneUseCase(
            photoService: photoSvc,
            embedder: sceneEmbedder,
            repository: sceneRepo
        )
        self.searchSceneUseCase = SearchBySceneUseCase(
            embedder: sceneEmbedder,
            repository: sceneRepo
        )

        // Show warning if we fell back to a stub embedder (face or scene).
        if let warning = embedderResult.warningMessage {
            state.userMessage = warning
        } else if let sceneWarning = sceneEmbedderResult.warningMessage {
            state.userMessage = sceneWarning
        }

        // Observe Remote Config for ad visibility.
        configCancellable = RemoteConfigManager.shared.$showAds
            .receive(on: DispatchQueue.main)
            .assign(to: \.showAds, on: self)

        // Check initial photo permission state for the warning card.
        checkPhotoPermission()

        // Re-check when the app returns from Settings.
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkPhotoPermission()
        }
    }

    // MARK: - Permission Warning Card

    func checkPhotoPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .limited:
            state.permissionWarning = .limited
        case .denied, .restricted:
            state.permissionWarning = .denied
        case .authorized:
            state.permissionWarning = .none
        case .notDetermined:
            state.permissionWarning = .none
        @unknown default:
            state.permissionWarning = .none
        }
        // Reset dismiss flag when permission level changes
        state.isWarningCardDismissed = false
    }

    func onDismissWarningCard() {
        state.isWarningCardDismissed = true
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
        state.visibleMatchCount = 0
        state.hasMoreMatches = false
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
        guard state.searchMode == .faces else { return }
        guard state.hasPhoto, !state.isBusy else { return }

        guard state.hasSelectedFaces else {
            state.userMessage = L10n.selectAtLeastOneFace
            state.showSettingsAction = false
            return
        }

        proceedWithPermissionFlow()
    }

    // MARK: - Search Mode / Text Search

    func onChangeSearchMode(_ mode: SearchMode) {
        guard state.searchMode != mode, !state.isBusy else { return }
        state.searchMode = mode
        // Switching modes clears the previous mode's results to avoid confusion.
        clearResults()
        state.isSelectionMode = false
        clearMessage()
    }

    func onTapTextSearch() {
        guard state.searchMode == .text, !state.isBusy else { return }
        guard state.hasSearchText else {
            state.userMessage = L10n.enterSearchText
            state.showSettingsAction = false
            return
        }
        proceedWithPermissionFlow()
    }

    func onTapSceneSearch() {
        guard state.searchMode == .scene, !state.isBusy else { return }
        guard state.hasSceneDescription else {
            state.userMessage = L10n.enterSceneDescription
            state.showSettingsAction = false
            return
        }
        proceedWithPermissionFlow()
    }

    /// Sets the scene description from a tappable example chip and runs the search.
    func onTapSceneExample(_ text: String) {
        guard !state.isBusy else { return }
        state.sceneDescription = text
        onTapSceneSearch()
    }

    /// Shared photo-permission gate used by both face and text searches. Routes
    /// to `startPipelineWithAdCheck` (which runs the active pipeline) or the
    /// appropriate permission dialog based on current authorization.
    private func proceedWithPermissionFlow() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        checkPhotoPermission()
        switch status {
        case .authorized:
            startPipelineWithAdCheck()
        case .limited:
            startPipelineWithAdCheck()
        case .notDetermined:
            // Show pre-permission explanation before triggering the system prompt.
            state.showPrePermissionDialog = true
        case .denied, .restricted:
            state.showDeniedAccessDialog = true
        @unknown default:
            state.userMessage = L10n.unableToAccessPhotoLibrary
        }
    }

    /// Decides whether to show a rewarded ad before running the pipeline.
    /// First `freeRuns` detections are ad-free, then every `adFrequency`-th shows an ad.
    private func startPipelineWithAdCheck() {
        detectionCount += 1

        let shouldShowAd = showAds
            && detectionCount > Self.freeRuns
            && (detectionCount - Self.freeRuns) % Self.adFrequency == 1

        if shouldShowAd {
            rewardedAdManager.showAd { [weak self] in
                guard let self else { return }
                Task { await self.runActivePipeline() }
            }
        } else {
            Task { await runActivePipeline() }
        }
    }

    /// Runs whichever pipeline matches the current search mode.
    private func runActivePipeline() async {
        switch state.searchMode {
        case .faces: await runPipeline()
        case .text:  await runTextPipeline()
        case .scene: await runScenePipeline()
        }
    }

    /// Called when user taps "Continue" on the pre-permission dialog.
    func onConfirmPrePermission() {
        state.showPrePermissionDialog = false
        Task {
            let result = await photoService.requestAuthorization()
            checkPhotoPermission()
            switch result {
            case .authorized:
                await runActivePipeline()
            case .limited:
                state.showLimitedAccessDialog = true
            case .denied, .restricted:
                state.showDeniedAccessDialog = true
            @unknown default:
                state.userMessage = L10n.unableToAccessPhotoLibrary
            }
        }
    }

    /// Called when user taps "Continue" on the limited-access dialog.
    func onContinueWithLimitedAccess() {
        state.showLimitedAccessDialog = false
        checkPhotoPermission()
        Task { await runActivePipeline() }
    }

    /// Called when user taps "Not now" on the denied dialog.
    func onDismissDeniedDialog() {
        state.showDeniedAccessDialog = false
        checkPhotoPermission()
    }

    private func runPipeline() async {
        let lastIndexed = metadataStore.loadLastIndexedDate()
        await runIndexing(since: lastIndexed)
        await runSearch()
    }

    private func runIndexing(since: Date?) async {
        state.isIndexing = true
        state.indexingProgress = 0
        state.indexingStatus = L10n.indexPreparing
        defer { state.isIndexing = false }

        do {
            let result = try await indexUseCase.execute(since: since) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.state.indexingProgress = progress.fraction
                    self?.state.indexingStatus = progress.status
                }
            }

            if result.scannedNewAssets == 0 {
                state.userMessage = L10n.noNewPhotosToIndex
            } else if result.indexedNewFaces > 0 {
                state.userMessage = L10n.indexingResultNew(
                    faces: result.indexedNewFaces,
                    photos: result.scannedNewAssets
                )
                try? metadataStore.saveLastIndexedDate(Date())
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
                selectedFaces: selectedBoxes,
                threshold: state.matchSensitivity
            )
            let models = results.map {
                MatchUiModel(
                    assetIdentifier: $0.assetIdentifier,
                    scorePercent: Int($0.similarityScore * 100)
                )
            }
            state.allMatches = models
            // Load first page
            let firstPage = min(Self.pageSize, models.count)
            state.matches = Array(models.prefix(firstPage))
            state.visibleMatchCount = firstPage
            state.hasMoreMatches = firstPage < models.count
            if state.matches.isEmpty {
                state.userMessage = L10n.noSimilarFacesFound
            }
        } catch {
            state.userMessage = error.localizedDescription
        }
    }

    // MARK: - Text Search Pipeline

    private func runTextPipeline() async {
        let lastIndexed = metadataStore.loadLastTextIndexedDate()
        await runTextIndexing(since: lastIndexed)
        await runTextSearch()
    }

    private func runTextIndexing(since: Date?) async {
        state.isIndexing = true
        state.indexingProgress = 0
        state.indexingStatus = L10n.indexPreparing
        defer { state.isIndexing = false }

        do {
            let result = try await indexTextUseCase.execute(since: since) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.state.indexingProgress = progress.fraction
                    self?.state.indexingStatus = progress.status
                }
            }
            // Advance the timestamp whenever we actually scanned new assets, so
            // text-less photos aren't re-OCR'd on every search.
            if result.scannedNewAssets > 0 {
                try? metadataStore.saveLastTextIndexedDate(Date())
            }
        } catch {
            state.userMessage = L10n.indexingFailed(error.localizedDescription)
        }
    }

    private func runTextSearch() async {
        let query = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        state.isSearching = true
        defer { state.isSearching = false }

        do {
            let results = try await searchTextUseCase.execute(query: query)
            let models = results.map {
                MatchUiModel(
                    assetIdentifier: $0.assetIdentifier,
                    scorePercent: Int($0.similarityScore * 100)
                )
            }
            state.allMatches = models
            let firstPage = min(Self.pageSize, models.count)
            state.matches = Array(models.prefix(firstPage))
            state.visibleMatchCount = firstPage
            state.hasMoreMatches = firstPage < models.count
            if state.matches.isEmpty {
                state.userMessage = L10n.noTextFound
            }
        } catch {
            state.userMessage = error.localizedDescription
        }
    }

    // MARK: - Scene Search Pipeline (CLIP)

    private func runScenePipeline() async {
        await reconcileSceneModelIfNeeded()
        let lastIndexed = metadataStore.loadLastSceneIndexedDate()
        await runSceneIndexing(since: lastIndexed)
        await runSceneSearch()
    }

    /// If the scene index was built by a different MobileCLIP model than the one
    /// now active (e.g. after swapping s0→s2, or stub→real), wipe it so we never
    /// compare vectors from different CLIP spaces. The next scan re-embeds fresh.
    private func reconcileSceneModelIfNeeded() async {
        guard metadataStore.loadSceneModelId() != sceneModelId else { return }
        #if DEBUG
        print("[PhotoMatchViewModel] Scene model changed → rebuilding index for \(sceneModelId)")
        #endif
        try? await sceneRepository.clear()
        try? metadataStore.resetSceneIndex(forModelId: sceneModelId)
    }

    private func runSceneIndexing(since: Date?) async {
        state.isIndexing = true
        state.indexingProgress = 0
        state.indexingStatus = L10n.indexPreparing
        defer { state.isIndexing = false }

        do {
            let result = try await indexSceneUseCase.execute(since: since) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.state.indexingProgress = progress.fraction
                    self?.state.indexingStatus = progress.status
                }
            }
            // Advance the timestamp whenever we scanned new assets, so already-seen
            // photos aren't re-embedded on every search.
            if result.scannedNewAssets > 0 {
                try? metadataStore.saveLastSceneIndexedDate(Date())
            }
        } catch {
            state.userMessage = L10n.indexingFailed(error.localizedDescription)
        }
    }

    private func runSceneSearch() async {
        let query = state.sceneDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        state.isSearching = true
        defer { state.isSearching = false }

        do {
            let results = try await searchSceneUseCase.execute(
                description: query,
                threshold: state.sceneSensitivity
            )
            let models = results.map {
                MatchUiModel(
                    assetIdentifier: $0.assetIdentifier,
                    scorePercent: Int($0.similarityScore * 100)
                )
            }
            state.allMatches = models
            let firstPage = min(Self.pageSize, models.count)
            state.matches = Array(models.prefix(firstPage))
            state.visibleMatchCount = firstPage
            state.hasMoreMatches = firstPage < models.count
            if state.matches.isEmpty {
                state.userMessage = L10n.noSceneMatches
            }
        } catch {
            state.userMessage = error.localizedDescription
        }
    }

    /// Clears the results grid and pagination state (shared by both modes).
    private func clearResults() {
        state.allMatches = []
        state.matches = []
        state.visibleMatchCount = 0
        state.hasMoreMatches = false
    }

    // MARK: - Match Selection

    /// A result was tapped: in selection mode this toggles its selection,
    /// otherwise it opens the full-screen image preview.
    func onTapMatch(id: UUID) {
        if state.isSelectionMode {
            onToggleMatchSelection(id: id)
        } else {
            guard let match = state.matches.first(where: { $0.id == id }) else { return }
            state.previewAssetIdentifier = match.assetIdentifier
        }
    }

    func onDismissPreview() {
        state.previewAssetIdentifier = nil
    }

    func onToggleMatchSelection(id: UUID) {
        guard state.isSelectionMode else { return }
        guard let idx = state.matches.firstIndex(where: { $0.id == id }) else { return }
        state.matches[idx].isSelected.toggle()
    }

    func onClearMatchSelection() {
        for i in state.matches.indices {
            state.matches[i].isSelected = false
        }
    }

    /// Toggles iOS-style "Select" mode for the results grid. Leaving the mode
    /// clears any current selection.
    func onToggleSelectionMode() {
        state.isSelectionMode.toggle()
        if !state.isSelectionMode {
            onClearMatchSelection()
        }
    }

    // MARK: - Save to Group

    /// The matches that a Save/Share action applies to: the current selection if
    /// any, otherwise every match. Returns the asset ids plus the counts the
    /// Save-to-Group sheet displays ("N photos · N faces").
    var saveToGroupPayload: (assetIdentifiers: [String], photoCount: Int, faceCount: Int) {
        let target = state.hasSelectedMatches ? state.selectedMatches : state.allMatches
        return (target.map(\.assetIdentifier), target.count, state.selectedFaces.count)
    }

    /// Called after the sheet successfully saves into a group: surface a
    /// confirmation and leave selection mode.
    func onGroupSaved(groupName: String) {
        state.userMessage = L10n.savedToGroup(groupName)
        state.showSettingsAction = false
        state.isSelectionMode = false
        onClearMatchSelection()
        ReviewPromptManager.registerSuccessfulSaveAndRequestReview()
    }

    // MARK: - Pagination

    private static let pageSize = 50

    func onLoadMoreMatches() {
        guard state.hasMoreMatches else { return }
        let nextCount = min(
            state.visibleMatchCount + Self.pageSize,
            state.allMatches.count
        )
        guard nextCount > state.visibleMatchCount else { return }
        let newItems = state.allMatches[state.visibleMatchCount..<nextCount]
        state.matches.append(contentsOf: newItems)
        state.visibleMatchCount = nextCount
        state.hasMoreMatches = nextCount < state.allMatches.count
    }

    // MARK: - Sharing

    func onShareMatches() {
        guard !state.matches.isEmpty else { return }

        shareCount += 1
        let shouldShowAd = showAds
            && shareCount > Self.freeRuns
            && (shareCount - Self.freeRuns) % Self.adFrequency == 1

        if shouldShowAd {
            rewardedAdManager.showAd { [weak self] in
                self?.performShare()
            }
        } else {
            performShare()
        }
    }

    private func performShare() {
        Task {
            state.isSearching = true
            defer { state.isSearching = false }
            // Share selected items, or all matches if none selected.
            let toShare = state.hasSelectedMatches
                ? state.selectedMatches
                : state.allMatches
            let ids = toShare.map(\.assetIdentifier)
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
