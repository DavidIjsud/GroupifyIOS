import SwiftUI

/// Everything the Save-to-Group sheet needs, handed up from the results screen.
struct SaveToGroupContext: Identifiable {
    let id = UUID()
    let assetIdentifiers: [String]
    let photoCount: Int
    let faceCount: Int
    /// Called after a successful save with the group name, so the caller can show
    /// a confirmation and exit selection mode.
    let onSaved: (String) -> Void
}

/// iOS-style bottom sheet for naming a new group (with live duplicate
/// validation that blocks) or adding the matches to an existing group.
///
/// Implemented as a custom overlay rather than a system `.sheet` so it matches
/// the design (rounded top, scrim, drag handle) and works on the iOS 15.6
/// deployment target without `presentationDetents`.
struct CreateGroupSheet: View {
    let context: SaveToGroupContext
    @ObservedObject var groupsVM: GroupsViewModel
    let onDismiss: () -> Void

    @State private var name = ""
    @State private var selectedExistingGroupId: String?
    @State private var appear = false
    @FocusState private var nameFocused: Bool

    // MARK: - Derived state

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var isDuplicate: Bool {
        !trimmedName.isEmpty && groupsVM.nameExists(trimmedName)
    }
    private var isAdding: Bool { selectedExistingGroupId != nil }
    private var addingGroup: PhotoGroup? {
        selectedExistingGroupId.flatMap { groupsVM.group(withId: $0) }
    }
    private var canCreate: Bool { !trimmedName.isEmpty && !isDuplicate }
    private var showAvailable: Bool { canCreate && !isAdding }
    private var showSuggestions: Bool { trimmedName.isEmpty && !isAdding }
    private var showExistingList: Bool {
        !isDuplicate && (isAdding || (!trimmedName.isEmpty && !groupsVM.groups.isEmpty))
    }

    private let suggestions = [
        L10n.groupSuggestionWeekend,
        L10n.groupSuggestionFamily,
        L10n.groupSuggestionSelfies,
        L10n.groupSuggestionTrip,
    ]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(appear ? 0.55 : 0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissSheet() }

            sheetCard
                .offset(y: appear ? 0 : 760)
        }
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { appear = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { nameFocused = true }
        }
    }

    // MARK: - Card

    private var sheetCard: some View {
        VStack(spacing: 0) {
            // drag handle
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 18)

            titleRow
            nameInput.padding(.top, 16)
            helperText
            sectionsArea
            primaryButton.padding(.top, 4)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
        .background(
            TopRoundedRectangle(radius: 28)
                .fill(AppTheme.card)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            TopRoundedRectangle(radius: 28)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.saveToGroup)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text("\(L10n.groupPhotosCount(context.photoCount)) · \(L10n.groupFacesCount(context.faceCount))")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textMuted)
            }
            Spacer()
            Button {
                dismissSheet()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Name input

    private var nameInput: some View {
        let borderColor: Color = isDuplicate ? AppTheme.danger
            : (showAvailable ? AppTheme.success : Color.clear)
        return HStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 18))
                .foregroundColor(AppTheme.textMuted)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.groupNameFieldLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
                    .textCase(.uppercase)
                TextField("", text: $name, prompt:
                    Text(L10n.groupNamePlaceholder).foregroundColor(.white.opacity(0.35)))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .tint(AppTheme.accent)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onChange(of: name) { _ in
                        // Typing always means "create new" — leave adding mode.
                        if !name.isEmpty { selectedExistingGroupId = nil }
                    }
                    .onTapGesture { selectedExistingGroupId = nil }
            }
            statusIcon
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isAdding ? 10 : 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 44/255, green: 44/255, blue: 46/255)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: 1.5))
        .opacity(isAdding ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.15), value: isAdding)
        .contentShape(Rectangle())
        .onTapGesture {
            if isAdding { selectedExistingGroupId = nil; nameFocused = true }
        }
    }

    @ViewBuilder private var statusIcon: some View {
        if showAvailable {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(AppTheme.success))
        } else if isDuplicate {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(AppTheme.danger))
        }
    }

    // MARK: - Helper text

    private var helperText: some View {
        Group {
            if isAdding {
                Button {
                    selectedExistingGroupId = nil
                    nameFocused = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                        Text(L10n.groupCreateNewInstead).fontWeight(.semibold)
                    }
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.accent)
                }
                .buttonStyle(.plain)
            } else if isDuplicate {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill").font(.system(size: 13))
                    Text(L10n.groupDuplicateError(trimmedName))
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.danger)
            } else if showAvailable {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                    Text(L10n.groupNameAvailable)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.success)
            } else {
                Text(L10n.groupHelperEmpty)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 22, alignment: .topLeading)
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }

    // MARK: - Suggestions / existing-group sections

    @ViewBuilder private var sectionsArea: some View {
        if showSuggestions {
            suggestionsSection.padding(.top, 16)
        }
        if showExistingList {
            existingSection.padding(.top, 16)
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.groupSuggestionsHeader)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textDim)
                .textCase(.uppercase)
                .padding(.leading, 4)
            FlowChips(items: suggestions) { s in
                name = s
                selectedExistingGroupId = nil
            }
        }
    }

    private var existingSection: some View {
        let shown = isAdding
            ? groupsVM.groups.filter { $0.id == selectedExistingGroupId }
            : Array(groupsVM.groups.prefix(2))
        return VStack(spacing: 0) {
            HStack {
                Text(isAdding ? L10n.groupAddingTo : L10n.groupOrAddToExisting)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textDim)
                    .textCase(.uppercase)
                Spacer()
                Text(isAdding
                    ? L10n.groupNewPhotosCount(context.photoCount)
                    : L10n.groupGroupsCount(groupsVM.groups.count))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ForEach(Array(shown.enumerated()), id: \.element.id) { idx, group in
                if idx > 0 { Divider().background(AppTheme.hairline) }
                existingRow(group)
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.cardHi))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(isAdding ? AppTheme.accentBorder : Color.clear, lineWidth: 1))
    }

    private func existingRow(_ group: PhotoGroup) -> some View {
        let selected = isAdding && group.id == selectedExistingGroupId
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedExistingGroupId = (selectedExistingGroupId == group.id) ? nil : group.id
            }
            if selected { nameFocused = true }
        } label: {
            HStack(spacing: 12) {
                StackedThumbnails(assetIdentifiers: group.assetIdentifiers)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 8) {
                        Text(group.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if selected {
                            Text("+\(context.photoCount)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                    Text(selected
                        ? L10n.groupAfterAdd(group.photoCount, group.photoCount + context.photoCount)
                        : L10n.groupPhotosCount(group.photoCount))
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(AppTheme.accent))
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(selected ? AppTheme.accentSoft : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Primary CTA

    private var primaryButton: some View {
        let enabled = isAdding || canCreate
        let label = isAdding
            ? L10n.groupAddToCTA(addingGroup?.name ?? "")
            : L10n.groupCreateCTA
        let icon = isAdding ? "plus" : "folder.badge.plus"
        return Button {
            performPrimary()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(label).font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Capsule().fill(enabled ? AppTheme.accent : AppTheme.accent.opacity(0.35)))
        }
        .disabled(!enabled)
        .padding(.top, 16)
    }

    // MARK: - Actions

    private func performPrimary() {
        if let group = addingGroup {
            groupsVM.addPhotos(
                context.assetIdentifiers,
                toGroupWithId: group.id,
                faceCount: context.faceCount
            )
            finish(groupName: group.name)
        } else if canCreate {
            if groupsVM.createGroup(
                name: trimmedName,
                assetIdentifiers: context.assetIdentifiers,
                faceCount: context.faceCount
            ) != nil {
                finish(groupName: trimmedName)
            }
        }
    }

    private func finish(groupName: String) {
        context.onSaved(groupName)
        dismissSheet()
    }

    private func dismissSheet() {
        nameFocused = false
        withAnimation(.easeIn(duration: 0.2)) { appear = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDismiss() }
    }
}

// MARK: - Stacked thumbnail preview (for existing-group rows)

private struct StackedThumbnails: View {
    let assetIdentifiers: [String]

    var body: some View {
        ZStack {
            let ids = Array(assetIdentifiers.prefix(3))
            if ids.isEmpty {
                RoundedRectangle(cornerRadius: 7).fill(AppTheme.cardHi)
                    .frame(width: 38, height: 38)
            } else {
                ForEach(Array(ids.enumerated()), id: \.offset) { j, id in
                    AssetImageView(assetIdentifier: id, cornerRadius: 7)
                        .frame(width: 38, height: 38)
                        .rotationEffect(.degrees(Double(j - 1) * 4))
                        .offset(x: CGFloat(j) * 3, y: CGFloat(j) * -2)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                        .zIndex(Double(10 - j))
                }
            }
        }
        .frame(width: 44, height: 38)
    }
}

// MARK: - Simple wrapping chip row

private struct FlowChips: View {
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        // 4 short suggestions fit comfortably in two rows of two.
        let pairs = stride(from: 0, to: items.count, by: 2).map {
            Array(items[$0..<min($0 + 2, items.count)])
        }
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        Button { onTap(item) } label: {
                            Text(item)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.accentText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(AppTheme.accent.opacity(0.14)))
                                .overlay(Capsule().stroke(AppTheme.accentBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Top-only rounded rectangle (iOS 15 compatible)

struct TopRoundedRectangle: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        p.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
