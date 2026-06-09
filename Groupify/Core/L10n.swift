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

    // MARK: - Search Mode (Faces / Text)

    nonisolated static var modeFaces: String {
        NSLocalizedString("mode.faces", comment: "Faces search mode toggle label")
    }
    nonisolated static var modeText: String {
        NSLocalizedString("mode.text", comment: "Text search mode toggle label")
    }
    nonisolated static var textSearchPlaceholder: String {
        NSLocalizedString("text.searchPlaceholder", comment: "Placeholder for the text search field")
    }
    nonisolated static var textSearchTitle: String {
        NSLocalizedString("text.searchTitle", comment: "Title above the text search field")
    }
    nonisolated static var textSearchButton: String {
        NSLocalizedString("text.searchButton", comment: "Button to start a text search")
    }
    nonisolated static var enterSearchText: String {
        NSLocalizedString("text.enterSearchText", comment: "Prompt when the search field is empty")
    }
    nonisolated static var noTextFound: String {
        NSLocalizedString("text.noTextFound", comment: "No photos matched the typed text")
    }

    /// "Reading text 3 of 50…"
    nonisolated static func readingTextProgress(current: Int, total: Int) -> String {
        String(format: NSLocalizedString(
            "text.readingProgress", comment: "OCR indexing X of Y status"
        ), current, total)
    }

    // MARK: - Search Mode (Scene / CLIP)

    nonisolated static var modeScene: String {
        NSLocalizedString("mode.scene", comment: "Scene (describe the photo) search mode toggle label")
    }
    nonisolated static var sceneSearchTitle: String {
        NSLocalizedString("scene.searchTitle", comment: "Title above the scene description field")
    }
    nonisolated static var sceneSearchPlaceholder: String {
        NSLocalizedString("scene.searchPlaceholder", comment: "Placeholder for the scene description field")
    }
    nonisolated static var sceneSearchButton: String {
        NSLocalizedString("scene.searchButton", comment: "Button to start a scene search")
    }
    nonisolated static var enterSceneDescription: String {
        NSLocalizedString("scene.enterDescription", comment: "Prompt when the scene field is empty")
    }
    nonisolated static var noSceneMatches: String {
        NSLocalizedString("scene.noMatches", comment: "No photos matched the scene description")
    }
    nonisolated static var sceneExamplesHeader: String {
        NSLocalizedString("scene.examplesHeader", comment: "Header above the example chips")
    }
    nonisolated static var sceneModelMissingWarning: String {
        NSLocalizedString("scene.modelMissingWarning", comment: "Shown when MobileCLIP models are absent (degraded scene matching)")
    }

    /// "Scanning scenes 3 of 50…"
    nonisolated static func scanningScenesProgress(current: Int, total: Int) -> String {
        String(format: NSLocalizedString(
            "scene.scanningProgress", comment: "CLIP scene indexing X of Y status"
        ), current, total)
    }

    /// The tappable example descriptions shown under the scene field.
    nonisolated static var sceneExamples: [String] {
        [
            NSLocalizedString("scene.example.beach", comment: "Scene example chip"),
            NSLocalizedString("scene.example.redDress", comment: "Scene example chip"),
            NSLocalizedString("scene.example.birthdayCake", comment: "Scene example chip"),
            NSLocalizedString("scene.example.sunset", comment: "Scene example chip"),
            NSLocalizedString("scene.example.dog", comment: "Scene example chip")
        ]
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

    // MARK: - Results Header (Groups flow)

    nonisolated static var similarPhotosTitle: String {
        NSLocalizedString("results.similarPhotos", comment: "Results header large title")
    }
    /// Plural via stringsdict: "239 Matches Found"
    nonisolated static func matchesFoundCount(_ count: Int) -> String {
        String(format: NSLocalizedString(
            "results.matchesFoundShort", comment: "Plural: X Matches Found"
        ), count)
    }
    nonisolated static var selectionSelect: String {
        NSLocalizedString("selection.select", comment: "Select pill label")
    }
    nonisolated static var selectionDone: String {
        NSLocalizedString("selection.done", comment: "Select pill label when active")
    }

    // MARK: - Save to Group / Sheet

    nonisolated static var saveToGroup: String {
        NSLocalizedString("group.saveToGroup", comment: "Save to Group button / sheet title")
    }
    nonisolated static func savedToGroup(_ name: String) -> String {
        String(format: NSLocalizedString(
            "group.saved", comment: "Saved-to-group confirmation"
        ), name)
    }
    /// Plural via stringsdict: "239 photos"
    nonisolated static func groupPhotosCount(_ count: Int) -> String {
        String(format: NSLocalizedString("group.photosCount", comment: "Plural: N photos"), count)
    }
    /// Plural via stringsdict: "1 face"
    nonisolated static func groupFacesCount(_ count: Int) -> String {
        String(format: NSLocalizedString("group.facesCount", comment: "Plural: N faces"), count)
    }
    /// Plural via stringsdict: "4 groups"
    nonisolated static func groupGroupsCount(_ count: Int) -> String {
        String(format: NSLocalizedString("group.groupsCount", comment: "Plural: N groups"), count)
    }
    /// Plural via stringsdict: "239 new photos"
    nonisolated static func groupNewPhotosCount(_ count: Int) -> String {
        String(format: NSLocalizedString("group.newPhotosCount", comment: "Plural: N new photos"), count)
    }
    nonisolated static var groupNameFieldLabel: String {
        NSLocalizedString("group.nameFieldLabel", comment: "Group name field label")
    }
    nonisolated static var groupNamePlaceholder: String {
        NSLocalizedString("group.namePlaceholder", comment: "Group name placeholder")
    }
    nonisolated static var groupHelperEmpty: String {
        NSLocalizedString("group.helperEmpty", comment: "Helper text when name empty")
    }
    nonisolated static var groupNameAvailable: String {
        NSLocalizedString("group.nameAvailable", comment: "Name available helper")
    }
    nonisolated static func groupDuplicateError(_ name: String) -> String {
        String(format: NSLocalizedString(
            "group.duplicateError", comment: "Duplicate name error"
        ), name)
    }
    nonisolated static var groupCreateNewInstead: String {
        NSLocalizedString("group.createNewInstead", comment: "Link to leave adding mode")
    }
    nonisolated static var groupSuggestionsHeader: String {
        NSLocalizedString("group.suggestionsHeader", comment: "Suggestions section header")
    }
    nonisolated static var groupOrAddToExisting: String {
        NSLocalizedString("group.orAddToExisting", comment: "Add-to-existing section header")
    }
    nonisolated static var groupAddingTo: String {
        NSLocalizedString("group.addingTo", comment: "Adding-to section header")
    }
    nonisolated static func groupAfterAdd(_ before: Int, _ after: Int) -> String {
        String(format: NSLocalizedString(
            "group.afterAdd", comment: "N -> M photos math line"
        ), before, after)
    }
    nonisolated static var groupCreateCTA: String {
        NSLocalizedString("group.createCTA", comment: "Create group CTA")
    }
    nonisolated static func groupAddToCTA(_ name: String) -> String {
        String(format: NSLocalizedString("group.addToCTA", comment: "Add to <group> CTA"), name)
    }
    nonisolated static var groupSuggestionWeekend: String {
        NSLocalizedString("group.suggestion.weekend", comment: "Suggestion chip")
    }
    nonisolated static var groupSuggestionFamily: String {
        NSLocalizedString("group.suggestion.family", comment: "Suggestion chip")
    }
    nonisolated static var groupSuggestionSelfies: String {
        NSLocalizedString("group.suggestion.selfies", comment: "Suggestion chip")
    }
    nonisolated static var groupSuggestionTrip: String {
        NSLocalizedString("group.suggestion.trip", comment: "Suggestion chip")
    }

    // MARK: - Groups Screen

    nonisolated static var groupsTitle: String {
        NSLocalizedString("groups.title", comment: "Groups screen title")
    }
    nonisolated static var groupsSearchPlaceholder: String {
        NSLocalizedString("groups.searchPlaceholder", comment: "Groups search placeholder")
    }
    nonisolated static var groupsEmptyTitle: String {
        NSLocalizedString("groups.emptyTitle", comment: "Empty groups title")
    }
    nonisolated static func groupsEmptyMessage(_ saveButton: String) -> String {
        String(format: NSLocalizedString(
            "groups.emptyMessage", comment: "Empty groups message; %@ is the Save button name"
        ), saveButton)
    }
    nonisolated static var groupsStartMatch: String {
        NSLocalizedString("groups.startMatch", comment: "Start a match button")
    }

    // MARK: - Group Detail

    nonisolated static var groupDetailLabel: String {
        NSLocalizedString("groupDetail.label", comment: "GROUP eyebrow label")
    }
    nonisolated static var groupDetailShare: String {
        NSLocalizedString("groupDetail.share", comment: "Share action")
    }
    nonisolated static var groupDetailAddMore: String {
        NSLocalizedString("groupDetail.addMore", comment: "Add more action")
    }
    nonisolated static var groupDelete: String {
        NSLocalizedString("groupDetail.delete", comment: "Delete group action")
    }
    nonisolated static func groupDeleteConfirmMessage(_ name: String) -> String {
        String(format: NSLocalizedString(
            "groupDetail.deleteConfirm", comment: "Delete confirmation message"
        ), name)
    }

    // MARK: - Tabs / Common / Dates

    nonisolated static var tabHome: String {
        NSLocalizedString("tab.home", comment: "Home tab")
    }
    nonisolated static var tabGroups: String {
        NSLocalizedString("tab.groups", comment: "Groups tab")
    }
    nonisolated static var commonCancel: String {
        NSLocalizedString("common.cancel", comment: "Cancel")
    }
    nonisolated static var dateToday: String {
        NSLocalizedString("date.today", comment: "Today")
    }
    nonisolated static var dateYesterday: String {
        NSLocalizedString("date.yesterday", comment: "Yesterday")
    }
}
