import Combine
import SwiftUI

/// Single source of truth for saved groups. Shared (via `environmentObject`) by
/// the Create-Group sheet, the Groups screen, and the Group-detail screen so a
/// save made from the results screen is immediately reflected everywhere.
///
/// Relies on the project-wide `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
/// (same as `PhotoMatchViewModel`); the repository/photo-service calls are
/// `nonisolated` and hop off the main thread.
final class GroupsViewModel: ObservableObject {
    @Published private(set) var groups: [PhotoGroup] = []
    @Published private(set) var isLoaded = false

    // Sharing a whole group through the iOS share sheet.
    @Published var isPreparingShare = false
    @Published var showShareSheet = false
    @Published var shareURLs: [URL] = []
    @Published var errorMessage: String?

    private let repository: any PhotoGroupRepository
    private let photoService: any PhotoLibraryService

    init(
        repository: any PhotoGroupRepository = FilePhotoGroupRepository(),
        photoService: any PhotoLibraryService = PhotoKitLibraryService()
    ) {
        self.repository = repository
        self.photoService = photoService
        Task { await load() }
    }

    // MARK: - Loading

    func load() async {
        defer { isLoaded = true }
        do {
            let loaded = try await repository.loadGroups()
            groups = loaded.sorted { $0.dateUpdated > $1.dateUpdated }
        } catch {
            groups = []
        }
    }

    // MARK: - Queries

    /// Total photos referenced across all groups (deduped per group, not globally).
    var totalPhotoCount: Int { groups.reduce(0) { $0 + $1.photoCount } }

    /// Case-insensitive, trimmed match against existing group names.
    func nameExists(_ name: String) -> Bool {
        let normalized = normalize(name)
        guard !normalized.isEmpty else { return false }
        return groups.contains { normalize($0.name) == normalized }
    }

    func group(withId id: String) -> PhotoGroup? {
        groups.first { $0.id == id }
    }

    // MARK: - Mutations

    /// Creates a new group. Returns `nil` if the name is blank or already taken.
    @discardableResult
    func createGroup(name: String, assetIdentifiers: [String], faceCount: Int) -> PhotoGroup? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !nameExists(trimmed) else { return nil }

        let group = PhotoGroup(
            name: trimmed,
            assetIdentifiers: dedupe(assetIdentifiers),
            faceCount: faceCount
        )
        groups.insert(group, at: 0)
        persist()
        return group
    }

    /// Adds photos to an existing group, skipping duplicates already present.
    func addPhotos(_ assetIdentifiers: [String], toGroupWithId id: String, faceCount: Int) {
        guard let idx = groups.firstIndex(where: { $0.id == id }) else { return }
        var merged = groups[idx].assetIdentifiers
        let existing = Set(merged)
        for asset in assetIdentifiers where !existing.contains(asset) {
            merged.append(asset)
        }
        groups[idx].assetIdentifiers = merged
        groups[idx].faceCount = max(groups[idx].faceCount, faceCount)
        groups[idx].dateUpdated = Date()
        resort()
        persist()
    }

    func deleteGroup(id: String) {
        groups.removeAll { $0.id == id }
        persist()
    }

    func renameGroup(id: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[idx].name = trimmed
        groups[idx].dateUpdated = Date()
        resort()
        persist()
    }

    // MARK: - Sharing

    func shareGroup(_ group: PhotoGroup) {
        guard !group.assetIdentifiers.isEmpty else { return }
        Task {
            isPreparingShare = true
            defer { isPreparingShare = false }
            do {
                let urls = try await photoService.exportForSharing(
                    assetIdentifiers: group.assetIdentifiers
                )
                shareURLs = urls
                showShareSheet = true
            } catch {
                errorMessage = L10n.couldNotExportImages
            }
        }
    }

    func onDismissShareSheet() {
        showShareSheet = false
        shareURLs = []
    }

    // MARK: - Private

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func dedupe(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var result = [String]()
        result.reserveCapacity(ids.count)
        for id in ids where !seen.contains(id) {
            seen.insert(id)
            result.append(id)
        }
        return result
    }

    private func resort() {
        groups.sort { $0.dateUpdated > $1.dateUpdated }
    }

    private func persist() {
        let snapshot = groups
        Task { try? await repository.saveAll(snapshot) }
    }
}
