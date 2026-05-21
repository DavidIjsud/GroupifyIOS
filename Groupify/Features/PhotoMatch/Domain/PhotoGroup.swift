import Foundation

/// A user-created collection ("group" / folder) of matched photos.
///
/// Stored as a *local reference*: it holds photo-library asset identifiers, not
/// the images themselves. The actual photos always stay in the user's library —
/// deleting a group never deletes photos.
struct PhotoGroup: Identifiable, Codable, Sendable, Equatable {
    let id: String
    var name: String
    /// Photo-library asset identifiers in this group (deduped, insertion order preserved).
    var assetIdentifiers: [String]
    /// Number of query faces that were searched when this group was created.
    var faceCount: Int
    let dateCreated: Date
    var dateUpdated: Date

    nonisolated var photoCount: Int { assetIdentifiers.count }

    init(
        id: String = UUID().uuidString,
        name: String,
        assetIdentifiers: [String],
        faceCount: Int,
        dateCreated: Date = Date(),
        dateUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.assetIdentifiers = assetIdentifiers
        self.faceCount = faceCount
        self.dateCreated = dateCreated
        self.dateUpdated = dateUpdated
    }
}
