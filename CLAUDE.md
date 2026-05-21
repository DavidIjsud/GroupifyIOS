# Groupify

iOS-only face-matching photo app (Swift + SwiftUI). The user uploads a photo containing
faces; the app detects faces, lets the user pick which face(s) to search for, scans the
on-device photo library for photos containing those faces, shows matches in a grid with a
similarity score, and lets the user share selected (or all) matches.

Bundle id: `com.palmyrasoft.groupify` · Single developer (David Garcia).

## Tech stack

- **Swift 5.0**, SwiftUI. App deployment target **iOS 15.6** (test targets are higher).
- **All ML runs on-device, no backend:**
  - **Apple Vision** (`VNDetectFaceRectanglesRequest`, revision 3) — face *detection*.
  - **TensorFlow Lite** (`facenet.tflite` in `Groupify/Resources/`) — face *embeddings*,
    160×160 RGB input → 128-dim L2-normalized vector.
  - **Accelerate / vDSP** — cosine-similarity search.
- **Firebase** — Remote Config (ad gating) + Crashlytics.
- **Google Mobile Ads (AdMob)** — banner, native, rewarded ads.
- Dependencies via **SPM**. Localized **English + Spanish** via `L10n` (`NSLocalizedString`).

## Architecture — Clean Architecture + MVVM

Two top-level groups: `Core/` (cross-cutting infra) and `Features/PhotoMatch/` (the one
feature), with the feature split into Domain / Data / Presentation.

```
Groupify/
  Core/
    Ads/            BannerAdView, NativeAdCell, RewardedAdManager
    Config/         RemoteConfigManager (Firebase Remote Config singleton)
    ImageUtils/     ImageNormalizer, FaceCropper
    PhotoPicking/   PHPicker (iOS15) + PhotosPicker (iOS16) + camera representables
    Search/         EmbeddingSearchEngine (vDSP cosine similarity)
    L10n.swift      Central localization helper
  Features/PhotoMatch/
    Domain/         Models, Protocols, *UseCase  (pure, framework-light)
    Data/           Vision/TFLite/Stub embedders, File repo, PhotoKit service, factory
    Presentation/   PhotoMatchViewModel + SwiftUI views (PhotoMatchScreen, chips, grid)
  GroupifyApp.swift / ContentView.swift
```

- **Protocol-driven boundaries** (in `Domain/Protocols.swift`): `FaceDetector`,
  `FaceEmbedder`, `FaceIndexRepository`, `PhotoLibraryService`. Swap implementations
  without touching use cases.
- **Use cases** are plain `Sendable` structs: `IndexLibraryUseCase`,
  `SearchByPhotoUseCase`, `DetectQueryFacesUseCase`.
- **Single ViewModel** (`PhotoMatchViewModel`, an `ObservableObject`) holds one
  `PhotoMatchUiState` struct. **Manual DI** is wired in the ViewModel's `init()`.
- `ContentView` just hosts `PhotoMatchScreen`.

## Core pipeline (the heart of the app)

1. **Detect query faces** (`DetectQueryFacesUseCase`): Vision finds faces in the uploaded
   image, sorted by area descending; largest is selected by default. UI shows them as
   circular chips with a bounding-box overlay.
2. **Index library** (`IndexLibraryUseCase`): incremental — only scans assets newer than
   the last-indexed timestamp (`IndexMetadataStore`), deduped by `assetIdentifier#faceIndex`.
   Per photo: 300×300 thumbnail → Vision detect → `FaceCropper` crop (15% padding) →
   FaceNet 128-d embedding.
3. **Search** (`SearchByPhotoUseCase` + `EmbeddingSearchEngine`): embed selected query
   faces, cosine-similarity (vDSP dot product on normalized vectors) over the whole index.
   Per asset keep best score across query faces; filter by threshold (default **0.40**),
   sort descending. Results paginate 50/page; native ads interleaved every 8 cells.
4. **Share** (`PhotoKitLibraryService.exportForSharing`): loads full-res images, writes
   JPEGs (q=0.85) to a temp dir, hands URLs to `UIActivityViewController`.

### Coordinate correctness (important, easy to break)

`ImageNormalizer.normalizeUpright` produces ONE canonical upright bitmap (strips EXIF
orientation). Both Vision detection AND `FaceCropper` run on that same bitmap, so bounding
boxes align. Vision's bottom-left origin is converted to **top-left origin** in
`VisionFaceDetector`. All `FaceBoundingBox` values are normalized 0…1, top-left origin.
If you touch detection, cropping, or the bbox overlay, preserve this contract.

## Persistence

`FileFaceIndexRepository` stores the index in Application Support / `GroupifyIndex/`:
- `face_index.json` — manifest: metadata + byte offset into the binary blob per face.
- `embeddings.bin` — contiguous Float32 vectors (128 dims × 4 bytes = 512 bytes each).
- New faces are **appended** (binary via `FileHandle`, JSON rewritten atomically).
- `index_metadata.json` (`IndexMetadataStore`) — last-indexed timestamp for incremental scans.

## Concurrency

- Project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so types default to MainActor.
  Use cases / data services are deliberately marked `nonisolated` to run off the main thread.
  Keep this in mind when adding methods — mark background work `nonisolated`.
- `TFLiteFaceEmbedder`'s `Interpreter` is NOT thread-safe; it's serialized behind an
  `NSLock` inside a `@unchecked Sendable` holder class.

## Monetization

- Ads gated by Firebase Remote Config key `show_ads`. `RemoteConfigManager` re-fetches on
  foreground. (Note: remote *default* is `false`, but `@Published showAds` starts `true`,
  so ads show until config resolves.)
- **Rewarded ads**: first 2 actions free, then every 3rd (`freeRuns=2`, `adFrequency=3`),
  before both Start Detection and Share.
- Banner ads above/below results; native ads every 8 grid cells.
- ATT / IDFA tracking request was intentionally removed (commented out in `GroupifyApp.swift`).

## Conventions

- Localize all user-facing strings through `L10n` (never hardcode). Keys live in
  `en.lproj` / `es.lproj` `Localizable.strings`.
- UI state flows one-way: View → ViewModel intent methods (`onTap…`) → mutate
  `state` → SwiftUI re-renders. Don't put logic in views.
- Theme tokens (colors, corner radius) are defined privately in `PhotoMatchScreen` (accent
  `#7B61FF`, dark background). Reuse them rather than introducing new literals.
- `#if DEBUG` guards all `print` logging.

## Known issues / cleanup candidates

- **Tests are empty** — `GroupifyTests` and the UI tests are placeholder stubs.
- **`Groupify/es 2.lproj`** appears to be a stray duplicate of `es.lproj` (Finder artifact).
- Sharing loads full-res images sequentially → can be slow / memory-heavy for many photos.

## Build / run

Open `Groupify.xcodeproj` in Xcode and run the `Groupify` scheme. Requires
`GoogleService-Info.plist` (committed) and the bundled `facenet.tflite`. If the model is
missing at runtime, `FaceEmbedderFactory` falls back to `StubFaceEmbedder` (degraded
matching) and surfaces a warning to the user.
