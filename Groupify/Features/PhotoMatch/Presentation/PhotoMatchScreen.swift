import SwiftUI

// MARK: - Design tokens

private enum Theme {
    static let background = Color(red: 14/255, green: 14/255, blue: 14/255)     // #0E0E0E
    static let cardBackground = Color(red: 28/255, green: 28/255, blue: 30/255) // #1C1C1E
    static let accent = Color(red: 123/255, green: 97/255, blue: 255/255)       // #7B61FF
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
        // iOS 16+ picker overlay (PhotosPicker is view-based)
        .overlay {
            if isIOS16Available {
                ios16PickerOverlay
            }
        }
    }

    // MARK: - Subviews

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
        Button {
            viewModel.onTapStartDetection()
        } label: {
            Text("Start Detection")
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.white)
                .background(viewModel.state.hasPhoto ? Theme.accent : Theme.accent.opacity(0.35))
                .cornerRadius(Theme.cornerRadius)
        }
        .disabled(!viewModel.state.hasPhoto)
    }

    private func messageBanner(_ text: String) -> some View {
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
        .padding(14)
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - iOS 16 picker

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
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Preview

struct PhotoMatchScreen_Previews: PreviewProvider {
    static var previews: some View {
        PhotoMatchScreen()
            .preferredColorScheme(.dark)
    }
}
