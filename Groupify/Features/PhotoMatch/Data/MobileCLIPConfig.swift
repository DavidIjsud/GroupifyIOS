import Foundation

/// Single source of truth for which MobileCLIP variant powers scene search.
///
/// To change model quality, set `variant` and bundle the matching
/// `mobileclip_<variant>_image.mlpackage` + `mobileclip_<variant>_text.mlpackage`
/// into `Resources/` (Xcode compiles them to `.mlmodelc`). All S-variants
/// (s0/s1/s2/blt) share the same 512-dim output and I/O contract, so swapping is
/// only a resource + this-constant change — no storage or code changes.
///
/// Because different variants produce embeddings in different vector spaces, the
/// scene index is tagged with `indexModelId`; a mismatch forces a one-time rebuild.
enum MobileCLIPConfig {
    /// Active variant: "s0" (fastest), "s1", "s2" (higher quality), "blt".
    static let variant = "s2"

    static var imageModelName: String { "mobileclip_\(variant)_image" }
    static var textModelName: String { "mobileclip_\(variant)_text" }

    /// Identifies which model built the scene index (e.g. "mobileclip_s2").
    static var indexModelId: String { "mobileclip_\(variant)" }
}
