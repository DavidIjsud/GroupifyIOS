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
                    if !viewModel.state.queryFaces.isEmpty {
                        faceChipsSection
                    } else if viewModel.state.isFaceLoading {
                        faceLoadingIndicator
                    }
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
            Text(L10n.appTitle)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text(L10n.appSubtitle)
                .font(.subheadline)
                .foregroundColor(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Query Photo Card (with bbox overlay)

    private var queryPhotoCard: some View {
        Button {
            viewModel.onTapPickPhoto()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .fill(Theme.cardBackground)
                    .frame(height: 260)

                if let image = viewModel.state.selectedImage {
                    queryImageWithOverlay(image)
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

            Text(L10n.tapToUpload)
                .font(.headline)
                .foregroundColor(.white)

            Text(L10n.selectFromGallery)
                .font(.caption)
                .foregroundColor(Theme.secondaryText)
        }
    }

    /// Shows the query image with a purple bounding box on the focused face.
    private func queryImageWithOverlay(_ image: UIImage) -> some View {
        GeometryReader { geo in
            let containerSize = geo.size
            let imageSize = image.size
            let fitted = aspectFitRect(imageSize: imageSize, in: containerSize)

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: containerSize.width, height: containerSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))

                // Focused face bounding box overlay
                if let box = viewModel.state.focusedBoundingBox {
                    let rect = bboxToDisplayRect(box: box, fitted: fitted)
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Theme.accent, lineWidth: 2.5)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.origin.x, y: rect.origin.y)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.state.focusedFaceId)
                }

                // Checkmark
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                        .padding(12)
                }
            }
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    /// Computes the rect a scaledToFit image occupies inside a container.
    private func aspectFitRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let scale = min(
            container.width / imageSize.width,
            container.height / imageSize.height
        )
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        let x = (container.width - w) / 2
        let y = (container.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Converts a normalized FaceBoundingBox (top-left origin, 0…1)
    /// to the display coordinate rect within the fitted image area.
    private func bboxToDisplayRect(box: FaceBoundingBox, fitted: CGRect) -> CGRect {
        CGRect(
            x: fitted.origin.x + CGFloat(box.x) * fitted.width,
            y: fitted.origin.y + CGFloat(box.y) * fitted.height,
            width: CGFloat(box.width) * fitted.width,
            height: CGFloat(box.height) * fitted.height
        )
    }

    // MARK: - Face Chips

    private var faceLoadingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(.white)
            Text(L10n.detectingFaces)
                .font(.subheadline)
                .foregroundColor(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var faceChipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title row
            HStack {
                Text(L10n.selectWhoToSearch)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                Spacer()

                Button(L10n.selectAll) { viewModel.onSelectAllFaces() }
                    .font(.caption.weight(.medium))
                    .foregroundColor(Theme.accent)

                Button(L10n.clear) { viewModel.onClearFaceSelection() }
                    .font(.caption.weight(.medium))
                    .foregroundColor(Theme.secondaryText)
            }

            // Chips scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.state.queryFaces) { face in
                        faceChip(face)
                    }
                }
                .padding(.vertical, 4)
            }

            // Selection count
            let sel = viewModel.state.selectedFaces.count
            let total = viewModel.state.queryFaces.count
            Text(L10n.facesSelected(selected: sel, total: total))
                .font(.caption)
                .foregroundColor(Theme.secondaryText)
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }

    private func faceChip(_ face: QueryFaceUiModel) -> some View {
        Button {
            viewModel.onToggleFace(id: face.id)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    if let thumb = face.thumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Theme.cardBackground)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(Theme.secondaryText)
                            )
                    }

                    if face.isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.accent)
                            .background(Circle().fill(Color.black).padding(-1))
                    }
                }
                .overlay(
                    Circle()
                        .stroke(
                            face.isSelected ? Theme.accent : Color.clear,
                            lineWidth: 2
                        )
                )

                Text(face.label)
                    .font(.system(size: 10))
                    .foregroundColor(
                        face.isSelected ? .white : Theme.secondaryText
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Buttons

    private var takePhotoButton: some View {
        Button {
            viewModel.onTapTakePhoto()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                Text(L10n.takeAPhoto)
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
        let canStart = viewModel.state.hasPhoto
            && viewModel.state.hasSelectedFaces
            && !viewModel.state.isBusy
        return Button {
            viewModel.onTapStartDetection()
        } label: {
            Text(L10n.startDetection)
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
                Text(L10n.matchSensitivity)
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
                Text(L10n.shareMatches(count: viewModel.state.matches.count))
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
                Text(L10n.searching)
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
                    Text(L10n.openSettings)
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
