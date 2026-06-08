import SwiftUI
import FirebaseCrashlytics

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

    /// Invoked when the user taps "Save to Group"; the host (RootTabView)
    /// presents the Create-Group sheet above the floating tab bar.
    private let onRequestSaveToGroup: (SaveToGroupContext) -> Void

    init(onRequestSaveToGroup: @escaping (SaveToGroupContext) -> Void = { _ in }) {
        self.onRequestSaveToGroup = onRequestSaveToGroup
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    searchModePicker

                    // Permission warning card
                    if viewModel.state.shouldShowWarningCard {
                        permissionWarningCard
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .animation(.easeInOut(duration: 0.25), value: viewModel.state.shouldShowWarningCard)
                    }

                    if viewModel.state.searchMode == .faces {
                        queryPhotoCard
                        if !viewModel.state.queryFaces.isEmpty {
                            faceChipsSection
                        } else if viewModel.state.isFaceLoading {
                            faceLoadingIndicator
                        }
                        takePhotoButton
                        startDetectionButton
                    } else {
                        textSearchCard
                        textSearchButton
                    }

                    if !viewModel.state.matches.isEmpty {
                        resultsHeader
                        resultsGrid
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                // Clear the floating tab bar, plus the floating action bar when results show.
                .padding(.bottom, viewModel.state.matches.isEmpty ? 120 : 250)
            }

            // Floating Save / Share bar, pinned above the tab bar.
            if !viewModel.state.matches.isEmpty {
                floatingActionBar
            }

            // Inline message banner — sits above the floating action bar when results show.
            if let message = viewModel.state.userMessage {
                VStack {
                    Spacer()
                    messageBanner(message)
                        .padding(.horizontal, 20)
                        .padding(.bottom, viewModel.state.matches.isEmpty ? 96 : 240)
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
        // Full-screen image preview (tap a result when Select mode is off)
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.state.previewAssetIdentifier != nil },
            set: { if !$0 { viewModel.onDismissPreview() } }
        )) {
            if let id = viewModel.state.previewAssetIdentifier {
                ImagePreviewView(
                    assetIdentifier: id,
                    onClose: { viewModel.onDismissPreview() }
                )
            }
        }
        // iOS 16+ picker overlay
        .overlay {
            if isIOS16Available {
                ios16PickerOverlay
            }
        }
        // Pre-permission explanation dialog
        .alert(
            L10n.permPreTitle,
            isPresented: $viewModel.state.showPrePermissionDialog
        ) {
            Button(L10n.permContinue) {
                viewModel.onConfirmPrePermission()
            }
        } message: {
            Text(L10n.permPreMessage)
        }
        // Limited access warning dialog
        .alert(
            L10n.permLimitedTitle,
            isPresented: $viewModel.state.showLimitedAccessDialog
        ) {
            Button(L10n.permContinue) {
                viewModel.onContinueWithLimitedAccess()
            }
            Button(L10n.openSettings) {
                viewModel.state.showLimitedAccessDialog = false
                viewModel.onOpenSettingsTapped()
            }
        } message: {
            Text(L10n.permLimitedMessage)
        }
        // Denied access dialog
        .alert(
            L10n.permDeniedTitle,
            isPresented: $viewModel.state.showDeniedAccessDialog
        ) {
            Button(L10n.openSettings) {
                viewModel.state.showDeniedAccessDialog = false
                viewModel.onOpenSettingsTapped()
            }
            Button(L10n.permNotNow, role: .cancel) {
                viewModel.onDismissDeniedDialog()
            }
        } message: {
            Text(L10n.permDeniedMessage)
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

    // MARK: - Search Mode Picker (Faces / Text)

    private var searchModePicker: some View {
        HStack(spacing: 6) {
            modeButton(.faces, icon: "face.smiling", label: L10n.modeFaces)
            modeButton(.text, icon: "text.magnifyingglass", label: L10n.modeText)
        }
        .padding(4)
        .background(Theme.cardBackground)
        .clipShape(Capsule())
    }

    private func modeButton(_ mode: SearchMode, icon: String, label: String) -> some View {
        let active = viewModel.state.searchMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.onChangeSearchMode(mode)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(active ? .white : Theme.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Capsule().fill(active ? Theme.accent : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Text Search Card

    private var textSearchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.textSearchTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.secondaryText)

                TextField(L10n.textSearchPlaceholder, text: $viewModel.state.searchText)
                    .foregroundColor(.white)
                    .tint(Theme.accent)
                    .submitLabel(.search)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .onSubmit { viewModel.onTapTextSearch() }

                if viewModel.state.hasSearchText {
                    Button {
                        viewModel.state.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(Theme.cornerRadius)
    }

    private var textSearchButton: some View {
        let canSearch = viewModel.state.hasSearchText && !viewModel.state.isBusy
        return Button {
            viewModel.onTapTextSearch()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                Text(L10n.textSearchButton)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(.white)
            .background(canSearch ? Theme.accent : Theme.accent.opacity(0.35))
            .cornerRadius(Theme.cornerRadius)
        }
        .disabled(!canSearch)
    }

    // MARK: - Permission Warning Card

    private var permissionWarningCard: some View {
        let isLimited = viewModel.state.permissionWarning == .limited
        return PermissionWarningCard(
            title: isLimited ? L10n.warningLimitedTitle : L10n.warningDeniedTitle,
            message: isLimited ? L10n.warningLimitedMessage : L10n.warningDeniedMessage,
            buttonLabel: L10n.openSettings,
            onButtonTapped: { viewModel.onOpenSettingsTapped() },
            onDismiss: { viewModel.onDismissWarningCard() }
        )
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

    // MARK: - Results Header (matches count + title + Select pill)

    private var resultsHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.matchesFoundCount(viewModel.state.allMatches.count))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.secondaryText)
                    .textCase(.uppercase)
                Text(L10n.similarPhotosTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.onToggleSelectionMode()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.state.isSelectionMode
                          ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 15, weight: .semibold))
                    Text(viewModel.state.isSelectionMode ? L10n.selectionDone : L10n.selectionSelect)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(viewModel.state.isSelectionMode ? .white : .white)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Capsule().fill(viewModel.state.isSelectionMode
                                           ? Theme.accent : Theme.cardBackground))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Results Grid

    private var resultsGrid: some View {
        let matches = viewModel.state.matches
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]

        return VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(matches) { match in
                    MatchThumbnailView(
                        assetIdentifier: match.assetIdentifier,
                        scorePercent: match.scorePercent,
                        isSelected: match.isSelected
                    )
                    .onTapGesture {
                        viewModel.onTapMatch(id: match.id)
                    }
                    .onAppear {
                        if match.id == matches.last?.id {
                            viewModel.onLoadMoreMatches()
                        }
                    }
                }
            }

            // Loading indicator for next page
            if viewModel.state.hasMoreMatches {
                ProgressView()
                    .tint(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Floating Action Bar (Save / Share, pinned above the tab bar)

    private var floatingActionBar: some View {
        VStack {
            Spacer()
            VStack(spacing: 10) {
                if viewModel.state.hasSelectedMatches {
                    Button {
                        viewModel.onClearMatchSelection()
                    } label: {
                        Text(L10n.clearSelection)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(Theme.secondaryText)
                    }
                }

                // Save to Group — secondary outline, sits above Share.
                Button {
                    requestSaveToGroup()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.badge.plus")
                        Text(L10n.saveToGroup).fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(.white)
                    .background(Theme.accent.opacity(0.12))
                    .cornerRadius(Theme.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .stroke(Theme.accent.opacity(0.45), lineWidth: 1.5)
                    )
                }

                // Share — primary filled.
                Button {
                    viewModel.onShareMatches()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        let count = viewModel.state.hasSelectedMatches
                            ? viewModel.state.selectedMatches.count
                            : viewModel.state.allMatches.count
                        Text(L10n.shareMatches(count: count))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(Theme.accent)
                    .cornerRadius(Theme.cornerRadius)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 90) // float above the tab bar
            .background(
                // Fade scrolled content out behind the buttons; let touches pass
                // through the fade so only the buttons are interactive.
                LinearGradient(
                    colors: [
                        Theme.background.opacity(0),
                        Theme.background.opacity(0.92),
                        Theme.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            )
            .animation(.easeInOut(duration: 0.2), value: viewModel.state.hasSelectedMatches)
        }
    }

    /// Builds the Save-to-Group context from the current matches (selected or all)
    /// and asks the host to present the sheet.
    private func requestSaveToGroup() {
        let payload = viewModel.saveToGroupPayload
        guard !payload.assetIdentifiers.isEmpty else { return }
        onRequestSaveToGroup(SaveToGroupContext(
            assetIdentifiers: payload.assetIdentifiers,
            photoCount: payload.photoCount,
            faceCount: payload.faceCount,
            onSaved: { name in viewModel.onGroupSaved(groupName: name) }
        ))
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
