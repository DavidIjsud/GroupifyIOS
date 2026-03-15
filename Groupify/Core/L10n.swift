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

    nonisolated static var noNewPhotosToIndex: String {
        NSLocalizedString("indexing.noNewPhotos", comment: "No new photos since last indexing")
    }

    /// "Indexed 5 new faces from 3 new photos"
    nonisolated static func indexingResultNew(faces: Int, photos: Int) -> String {
        String(format: NSLocalizedString(
            "indexing.resultNew",
            comment: "Indexing summary: X new faces from Y new photos"
        ), faces, photos)
    }

    nonisolated static var indexReset: String {
        NSLocalizedString("indexing.reset", comment: "Index has been reset confirmation")
    }

    nonisolated static var resetIndexButton: String {
        NSLocalizedString("button.resetIndex", comment: "DEBUG button to clear the face index")
    }

    // MARK: - Match Selection

    nonisolated static var clearSelection: String {
        NSLocalizedString("matches.clearSelection", comment: "Clear photo selection button")
    }

    // MARK: - Permission Dialogs

    nonisolated static var permPreTitle: String {
        NSLocalizedString("perm.preTitle", comment: "Pre-permission dialog title")
    }
    nonisolated static var permPreMessage: String {
        NSLocalizedString("perm.preMessage", comment: "Pre-permission dialog message")
    }
    nonisolated static var permContinue: String {
        NSLocalizedString("perm.continue", comment: "Continue button on permission dialogs")
    }
    nonisolated static var permLimitedTitle: String {
        NSLocalizedString("perm.limitedTitle", comment: "Limited access dialog title")
    }
    nonisolated static var permLimitedMessage: String {
        NSLocalizedString("perm.limitedMessage", comment: "Limited access dialog message")
    }
    nonisolated static var permDeniedTitle: String {
        NSLocalizedString("perm.deniedTitle", comment: "Denied access dialog title")
    }
    nonisolated static var permDeniedMessage: String {
        NSLocalizedString("perm.deniedMessage", comment: "Denied access dialog message")
    }
    nonisolated static var permNotNow: String {
        NSLocalizedString("perm.notNow", comment: "Not now button on denied dialog")
    }

    // MARK: - Permission Warning Card

    nonisolated static var warningLimitedTitle: String {
        NSLocalizedString("warning.limitedTitle", comment: "Limited access warning card title")
    }
    nonisolated static var warningLimitedMessage: String {
        NSLocalizedString("warning.limitedMessage", comment: "Limited access warning card message")
    }
    nonisolated static var warningDeniedTitle: String {
        NSLocalizedString("warning.deniedTitle", comment: "Denied access warning card title")
    }
    nonisolated static var warningDeniedMessage: String {
        NSLocalizedString("warning.deniedMessage", comment: "Denied access warning card message")
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
