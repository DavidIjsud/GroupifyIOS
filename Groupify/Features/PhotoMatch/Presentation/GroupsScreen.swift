import SwiftUI

/// Identifiable reference used to drive the detail full-screen cover by id, so the
/// detail screen always reads the live group from the shared store.
private struct GroupRef: Identifiable { let id: String }

/// New "Groups" destination: browse saved collections of matched photos.
/// Empty state on first run, otherwise a 2-column grid of group cards.
struct GroupsScreen: View {
    @EnvironmentObject private var groupsVM: GroupsViewModel

    /// Switches the app back to the Home tab to start a new match.
    var onStartMatch: () -> Void = {}

    @State private var showSearch = false
    @State private var searchText = ""
    @State private var presentedGroup: GroupRef?

    private var filteredGroups: [PhotoGroup] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return groupsVM.groups }
        return groupsVM.groups.filter { $0.name.lowercased().contains(q) }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if showSearch { searchField }

                if groupsVM.groups.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(filteredGroups) { group in
                                Button {
                                    presentedGroup = GroupRef(id: group.id)
                                } label: {
                                    GroupCard(group: group)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 120) // clear floating tab bar
                    }
                }
            }
        }
        .fullScreenCover(item: $presentedGroup) { ref in
            GroupDetailScreen(groupId: ref.id, onAddMore: {
                presentedGroup = nil
                onStartMatch()
            })
            .environmentObject(groupsVM)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.groupsTitle)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                if !groupsVM.groups.isEmpty {
                    Text("\(L10n.groupGroupsCount(groupsVM.groups.count)) · \(L10n.groupPhotosCount(groupsVM.totalPhotoCount))")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            Spacer()
            if !groupsVM.groups.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSearch.toggle()
                        if !showSearch { searchText = "" }
                    }
                } label: {
                    Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(AppTheme.card))
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(AppTheme.textMuted)
            TextField("", text: $searchText, prompt:
                Text(L10n.groupsSearchPlaceholder).foregroundColor(AppTheme.textMuted))
                .foregroundColor(.white)
                .tint(AppTheme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.card))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            folderHero.padding(.bottom, 28)
            Text(L10n.groupsEmptyTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 8)
            Text(L10n.groupsEmptyMessage(L10n.saveToGroup))
                .font(.system(size: 15))
                .foregroundColor(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 280)
            Button {
                onStartMatch()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text(L10n.groupsStartMatch).fontWeight(.bold)
                }
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(.horizontal, 26)
                .frame(height: 50)
                .background(Capsule().fill(AppTheme.accent))
            }
            .padding(.top, 28)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    private var folderHero: some View {
        ZStack {
            ForEach([2, 1, 0], id: \.self) { i in
                RoundedRectangle(cornerRadius: 18)
                    .fill(i == 0 ? AppTheme.accent
                          : (i == 1 ? Color(red: 61/255, green: 47/255, blue: 112/255)
                             : Color(red: 31/255, green: 26/255, blue: 46/255)))
                    .frame(width: 124, height: 92)
                    .opacity(i == 0 ? 1 : 0.55)
                    .rotationEffect(.degrees(Double(i - 1) * 4))
                    .offset(x: CGFloat(i) * 8 - 8, y: CGFloat(i) * 6)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
                    .overlay(
                        Group {
                            if i == 0 {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 36, weight: .regular))
                                    .foregroundColor(.white)
                                    .offset(x: -8, y: 0)
                            }
                        }
                    )
            }
        }
        .frame(width: 140, height: 120)
    }
}

// MARK: - Group card

struct GroupCard: View {
    let group: PhotoGroup

    private var collageIds: [String] { Array(group.assetIdentifiers.prefix(4)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            collage
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(L10n.groupFacesCount(group.faceCount))
                    Text("·").foregroundColor(AppTheme.textDim)
                    Text(RelativeDate.string(from: group.dateUpdated))
                }
                .font(.system(size: 12))
                .foregroundColor(AppTheme.textMuted)
                .lineLimit(1)
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 2)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(AppTheme.card))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.hairline, lineWidth: 1))
    }

    private var collage: some View {
        ZStack(alignment: .bottomTrailing) {
            GeometryReader { geo in
                let cell = (geo.size.width - 2) / 2
                LazyVGrid(columns: [GridItem(.fixed(cell), spacing: 2),
                                    GridItem(.fixed(cell), spacing: 2)], spacing: 2) {
                    ForEach(0..<4, id: \.self) { i in
                        if i < collageIds.count {
                            AssetImageView(assetIdentifier: collageIds[i])
                                .frame(width: cell, height: cell)
                        } else {
                            AppTheme.cardHi.frame(width: cell, height: cell)
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("\(group.photoCount)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.65)))
                .padding(8)
        }
    }
}

// MARK: - Relative date helper

enum RelativeDate {
    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    static func string(from date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return L10n.dateToday }
        if Calendar.current.isDateInYesterday(date) { return L10n.dateYesterday }
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
