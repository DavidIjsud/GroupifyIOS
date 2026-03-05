import Foundation

/// Centralized localization helper using `NSLocalizedString` for iOS 15+ compatibility.
/// All members are `nonisolated` so they can be called from background contexts
/// (the project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
enum L10n {

    // MARK: - Header

    nonisolated static var appTitle: String {
        NSLocalizedString("header.title", comment: "App title shown at top of screen")
    }
    nonisolated static var appSubtitle: String {
        NSLocalizedString("header.subtitle", comment: "Subtitle under app title")
    }

    // MARK: - Query Photo Card

    nonisolated static var tapToUpload: String {
        NSLocalizedString("card.tapToUpload", comment: "Prompt to upload a photo")
    }
    nonisolated static var selectFromGallery: String {
        NSLocalizedString("card.selectFromGallery", comment: "Hint to select from gallery")
    }

    // MARK: - Face Chips

    nonisolated static var detectingFaces: String {
        NSLocalizedString("faces.detecting", comment: "Loading indicator while detecting faces")
    }
    nonisolated static var selectWhoToSearch: String {
        NSLocalizedString("faces.selectWhoToSearch", comment: "Title for face chips section")
    }
    nonisolated static var selectAll: String {
        NSLocalizedString("faces.selectAll", comment: "Button to select all faces")
    }
    nonisolated static var clear: String {
        NSLocalizedString("faces.clear", comment: "Button to clear face selection")
    }

    /// "Face 1", "Face 2", etc.
    nonisolated static func faceLabel(_ index: Int) -> String {
        String(format: NSLocalizedString(
            "faces.label", comment: "Label for a face chip, e.g. Face 1"
        ), index)
    }

    /// Uses stringsdict for plurals: "2 of 3 faces selected"
    nonisolated static func facesSelected(selected: Int, total: Int) -> String {
        let format = NSLocalizedString(
            "faces.selectedCount",
            comment: "Plural: X of Y face(s) selected"
        )
        return String(format: format, selected, total)
    }

    // MARK: - Buttons

    nonisolated static var takeAPhoto: String {
        NSLocalizedString("button.takePhoto", comment: "Take a Photo button")
    }
    nonisolated static var startDetection: String {
        NSLocalizedString("button.startDetection", comment: "Start Detection button")
    }
    nonisolated static var openSettings: String {
        NSLocalizedString("button.openSettings", comment: "Open Settings button")
    }

    /// "Share Matches (5)"
    nonisolated static func shareMatches(count: Int) -> String {
        String(format: NSLocalizedString(
            "button.shareMatches", comment: "Share Matches button with count"
        ), count)
    }

    // MARK: - Sensitivity Slider

    nonisolated static var matchSensitivity: String {
        NSLocalizedString("slider.matchSensitivity", comment: "Match Sensitivity slider label")
    }

    // MARK: - Overlays

    nonisolated static var searching: String {
        NSLocalizedString("overlay.searching", comment: "Searching overlay text")
    }

    // MARK: - Messages (ViewModel)

    nonisolated static var cameraNotAvailable: String {
        NSLocalizedString("message.cameraNotAvailable", comment: "Camera not available message")
    }
    nonisolated static var cameraPermissionDenied: String {
        NSLocalizedString("message.cameraPermissionDenied", comment: "Camera permission denied")
    }
    nonisolated static var unableToAccessCamera: String {
        NSLocalizedString("message.unableToAccessCamera", comment: "Unknown camera error")
    }
    nonisolated static var selectAtLeastOneFace: String {
        NSLocalizedString("message.selectAtLeastOneFace", comment: "No face selected warning")
    }
    nonisolated static var photoLibraryAccessRequired: String {
        NSLocalizedString("message.photoLibraryAccessRequired", comment: "Photo library access needed")
    }
    nonisolated static var photoLibraryAccessDenied: String {
        NSLocalizedString("message.photoLibraryAccessDenied", comment: "Photo library access denied")
    }
    nonisolated static var unableToAccessPhotoLibrary: String {
        NSLocalizedString("message.unableToAccessPhotoLibrary", comment: "Unknown photo library error")
    }
    nonisolated static var noSimilarFacesFound: String {
        NSLocalizedString("message.noSimilarFaces", comment: "No matches found hint")
    }
    nonisolated static var couldNotExportImages: String {
        NSLocalizedString("message.couldNotExport", comment: "Export for sharing failed")
    }

    /// "Indexing failed: <error>"
    nonisolated static func indexingFailed(_ error: String) -> String {
        String(format: NSLocalizedString(
            "message.indexingFailed", comment: "Indexing error with detail"
        ), error)
    }

    // MARK: - Indexing Progress

    nonisolated static var indexPreparing: String {
        NSLocalizedString("indexing.preparing", comment: "Indexing preparing status")
    }
    nonisolated static var indexUpToDate: String {
        NSLocalizedString("indexing.upToDate", comment: "Index is already current")
    }

    /// "Indexing 3 of 50…"
    nonisolated static func indexingProgress(current: Int, total: Int) -> String {
        String(format: NSLocalizedString(
            "indexing.progress", comment: "Indexing X of Y status"
        ), current, total)
    }

    // MARK: - Use Case Errors

    nonisolated static var errorInvalidImage: String {
        NSLocalizedString("error.invalidImage", comment: "Image could not be processed")
    }
    nonisolated static var errorNoFacesDetected: String {
        NSLocalizedString("error.noFacesDetected", comment: "No faces found in photo")
    }
    nonisolated static var errorSelectAtLeastOneFace: String {
        NSLocalizedString("error.selectAtLeastOneFace", comment: "No face selected for search")
    }
    nonisolated static var errorCropFailed: String {
        NSLocalizedString("error.cropFailed", comment: "Face crop failed")
    }
    nonisolated static var errorThumbnailFailed: String {
        NSLocalizedString("error.thumbnailFailed", comment: "Photo thumbnail load failed")
    }
    nonisolated static var errorFullImageFailed: String {
        NSLocalizedString("error.fullImageFailed", comment: "Full photo load failed")
    }

    // MARK: - Indexing Result

    /// "Indexed 5 new faces (skipped 12 already indexed)"
    nonisolated static func indexingResult(indexedNew: Int, skippedExisting: Int) -> String {
        String(format: NSLocalizedString(
            "indexing.result",
            comment: "Indexing summary: X new, Y skipped"
        ), indexedNew, skippedExisting)
    }

    nonisolated static var indexReset: String {
        NSLocalizedString("indexing.reset", comment: "Index has been reset confirmation")
    }

    nonisolated static var resetIndexButton: String {
        NSLocalizedString("button.resetIndex", comment: "DEBUG button to clear the face index")
    }

    // MARK: - Results

    /// Uses stringsdict for plurals: "3 Similar Matches Found"
    nonisolated static func similarMatchesFound(count: Int) -> String {
        let format = NSLocalizedString(
            "results.matchesFound",
            comment: "Plural: X Similar Match(es) Found"
        )
        return String(format: format, count)
    }
}
