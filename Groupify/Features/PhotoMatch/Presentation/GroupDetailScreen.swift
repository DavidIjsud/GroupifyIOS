import SwiftUI

/// Drill-in view for a single saved group. Reads the live group from the shared
/// store by id, so renames / additions / deletion reflect immediately.
struct GroupDetailScreen: View {
    let groupId: String
    var onAddMore: () -> Void = {}

    @EnvironmentObject private var groupsVM: GroupsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showMenu = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            if let group = groupsVM.group(withId: groupId) {
                content(group)
            } else {
                // Group was deleted — close.
                Color.clear.onAppear { dismiss() }
            }

            if groupsVM.isPreparingShare {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    ProgressView().tint(AppTheme.accent).scaleEffect(1.4)
                }
            }
        }
        .sheet(isPresented: $groupsVM.showShareSheet,
               onDismiss: { groupsVM.onDismissShareSheet() }) {
            ShareSheetView(items: groupsVM.shareURLs)
        }
    }

    private func content(_ group: PhotoGroup) -> some View {
        VStack(spacing: 0) {
            navBar(group)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerBlock(group)
                    actionRow(group)
                    grid(group)
                }
            }
        }
    }

    // MARK: - Nav bar

    private func navBar(_ group: PhotoGroup) -> some View {
        HStack {
            circleButton("chevron.left") { dismiss() }
            Spacer()
            circleButton("ellipsis") { showMenu = true }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .confirmationDialog("", isPresented: $showMenu, titleVisibility: .hidden) {
            Button(L10n.groupDelete, role: .destructive) {
                groupsVM.deleteGroup(id: groupId)
                dismiss()
            }
            Button(L10n.commonCancel, role: .cancel) {}
        } message: {
            Text(L10n.groupDeleteConfirmMessage(group.name))
        }
    }

    private func circleButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(AppTheme.card))
        }
    }

    // MARK: - Header

    private func headerBlock(_ group: PhotoGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.groupDetailLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.accent)
                .textCase(.uppercase)
                .padding(.bottom, 6)
            Text(group.name)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
            HStack(spacing: 8) {
                Text(L10n.groupPhotosCount(group.photoCount))
                Text("·").foregroundColor(AppTheme.textDim)
                Text(L10n.groupFacesCount(group.faceCount))
            }
            .font(.subheadline)
            .foregroundColor(AppTheme.textMuted)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 14)
    }

    // MARK: - Actions

    private func actionRow(_ group: PhotoGroup) -> some View {
        HStack(spacing: 8) {
            Button {
                groupsVM.shareGroup(group)
            } label: {
                actionLabel("square.and.arrow.up", L10n.groupDetailShare, filled: true)
            }
            Button {
                onAddMore()
            } label: {
                actionLabel("folder.badge.plus", L10n.groupDetailAddMore, filled: false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private func actionLabel(_ icon: String, _ title: String, filled: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
            Text(title).font(.system(size: 15, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(filled ? AppTheme.accent : AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(filled ? Color.clear : AppTheme.hairline, lineWidth: 1)
        )
    }

    // MARK: - Grid

    private func grid(_ group: PhotoGroup) -> some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(group.assetIdentifiers, id: \.self) { id in
                AssetImageView(assetIdentifier: id, cornerRadius: 14)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
    }
}
