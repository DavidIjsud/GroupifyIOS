import SwiftUI

// MARK: - Design tokens

private enum Theme {
    static let background = Color(red: 14/255, green: 14/255, blue: 14/255)       // #0E0E0E
    static let cardBackground = Color(red: 28/255, green: 28/255, blue: 30/255)   // #1C1C1E
    static let accent = Color(red: 123/255, green: 97/255, blue: 255/255)         // #7B61FF
    static let secondaryText = Color(red: 158/255, green: 158/255, blue: 158/255) // #9E9E9E
    static let cornerRadius: CGFloat = 16
}

// MARK: - Screen

struct PhotoMatchScreen: View {
    @StateObject private var viewModel = PhotoMatchViewModel()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    queryPhotoCard
                    takePhotoButton
                    startDetectionButton
                    sensitivitySlider
                    if !viewModel.state.matches.isEmpty {
                        resultsGrid
                        shareMatchesButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }

            // Inline message banner
            if let message = viewModel.state.userMessage {
                VStack {
                    Spacer()
                    messageBanner(message)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeInOut(duration: 0.25), value: viewModel.state.userMessage)
            }

            // Overlays
            if viewModel.state.isIndexing {
                indexingOverlay
            }
            if viewModel.state.isSearching {
                searchingOverlay
            }
        }
        // iOS 15 picker sheet
        .sheet(isPresented: Binding(
            get: { viewModel.state.isPicking && !isIOS16Available },
            set: { if !$0 { viewModel.onPickCancelled() } }
        )) {
            PHPickerRepresentable(
                onPicked: { viewModel.onPickedPhoto(image: $0) },
                onCancelled: { viewModel.onPickCancelled() }
            )
        }
        // Camera sheet
        .sheet(isPresented: $viewModel.state.isTakingPhoto) {
            ImagePickerCameraRepresentable(
                onPicked: { viewModel.onCameraPicked(image: $0) },
                onCancelled: { viewModel.onCameraCancelled() }
            )
            .ignoresSafeArea()
        }
        // Share sheet
        .sheet(isPresented: $viewModel.state.showShareSheet,
               onDismiss: { viewModel.onDismissShareSheet() }) {
            ShareSheetView(items: viewModel.state.shareURLs)
        }
        // iOS 16+ picker overlay
        .overlay {
            if isIOS16Available {
                ios16PickerOverlay
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("PhotoMatch")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text("Find similar photos instantly")
                .font(.subheadline)
                .foregroundColor(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Query Photo Card

    private var queryPhotoCard: some View {
        Button {
            viewModel.onTapPickPhoto()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(Theme.cardBackground)
                    .frame(height: 260)

                if let image = viewModel.state.selectedImage {
                    selectedImageContent(image)
                } else {
                    emptyCardContent
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyCardContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundColor(Theme.accent)

            Text("Tap to upload a photo")
                .font(.headline)
                .foregroundColor(.white)

            Text("Select from your gallery")
                .font(.caption)
                .foregroundColor(Theme.secondaryText)
        }
    }

    private func selectedImageContent(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))

            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
                .padding(12)
        }
    }

    // MARK: - Buttons

    private var takePhotoButton: some View {
        Button {
            viewModel.onTapTakePhoto()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                Text("Take a Photo")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(.white)
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadius)
        }
    }

    private var startDetectionButton: some View {
        let canStart = viewModel.state.hasPhoto && !viewModel.state.isBusy
        return Button {
            viewModel.onTapStartDetection()
        } label: {
            Text("Start Detection")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.white)
                .background(canStart ? Theme.accent : Theme.accent.opacity(0.35))
                .cornerRadius(Theme.cornerRadius)
        }
        .disabled(!canStart)
    }

    // MARK: - Sensitivity Slider

    private var sensitivitySlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Match Sensitivity")
                    .font(.subheadline)
                    .foregroundColor(Theme.secondaryText)
                Spacer()
                Text("\(Int(viewModel.state.matchSensitivity * 100))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.white)
            }
            Slider(
                value: Binding(
                    get: { viewModel.state.matchSensitivity },
                    set: { viewModel.onSensitivityChanged(value: $0) }
                ),
                in: 0.60...0.95,
                step: 0.01
            )
            .tint(Theme.accent)
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
        .opacity(viewModel.state.allMatches.isEmpty ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: viewModel.state.allMatches.isEmpty)
    }

    // MARK: - Results Grid

    private var resultsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ],
            spacing: 8
        ) {
            ForEach(viewModel.state.matches) { match in
                MatchThumbnailView(
                    assetIdentifier: match.assetIdentifier,
                    scorePercent: match.scorePercent
                )
            }
        }
    }

    private var shareMatchesButton: some View {
        Button {
            viewModel.onShareMatches()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text("Share Matches (\(viewModel.state.matches.count))")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(.white)
            .background(Theme.accent)
            .cornerRadius(Theme.cornerRadius)
        }
    }

    // MARK: - Overlays

    private var indexingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView(value: viewModel.state.indexingProgress)
                    .progressViewStyle(.circular)
                    .tint(Theme.accent)
                    .scaleEffect(1.5)
                Text(viewModel.state.indexingStatus)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text("\(Int(viewModel.state.indexingProgress * 100))%")
                    .font(.title2.monospacedDigit().bold())
                    .foregroundColor(Theme.accent)
            }
            .padding(32)
            .background(Theme.cardBackground)
            .cornerRadius(20)
        }
    }

    private var searchingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Theme.accent)
                    .scaleEffect(1.5)
                Text("Searching…")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(Theme.cardBackground)
            .cornerRadius(20)
        }
    }

    // MARK: - Message Banner

    private func messageBanner(_ text: String) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(2)

                Spacer()

                Button {
                    viewModel.onDismissMessage()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.secondaryText)
                }
            }

            if viewModel.state.showSettingsAction {
                Button {
                    viewModel.onOpenSettingsTapped()
                } label: {
                    Text("Open Settings")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.accent.opacity(0.15))
                        .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - iOS 16 Picker

    private var isIOS16Available: Bool {
        if #available(iOS 16.0, *) { return true }
        return false
    }

    @ViewBuilder
    private var ios16PickerOverlay: some View {
        if #available(iOS 16.0, *) {
            PhotosPickerSheet(
                isPresented: $viewModel.state.isPicking,
                onPicked: { viewModel.onPickedPhoto(image: $0) },
                onCancelled: { viewModel.onPickCancelled() }
            )
        }
    }
}

// MARK: - Share Sheet

struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController, context: Context
    ) {}
}

// MARK: - Preview

struct PhotoMatchScreen_Previews: PreviewProvider {
    static var previews: some View {
        PhotoMatchScreen()
            .preferredColorScheme(.dark)
    }
}
