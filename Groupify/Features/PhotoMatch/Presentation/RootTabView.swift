import SwiftUI

enum AppTab: Hashable { case home, groups }

/// App root: hosts the Home (PhotoMatch) and Groups destinations behind a custom
/// floating tab bar (matching the fetched design), and presents the Save-to-Group
/// sheet above the tab bar.
///
/// Both screens stay in the hierarchy (toggled by opacity) so each keeps its own
/// `@StateObject` state across tab switches — switching to Groups never resets an
/// in-progress match on Home.
struct RootTabView: View {
    @StateObject private var groupsVM = GroupsViewModel()
    @State private var selectedTab: AppTab = .home
    @State private var saveContext: SaveToGroupContext?

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()

            PhotoMatchScreen(onRequestSaveToGroup: { ctx in
                saveContext = ctx
            })
            .opacity(selectedTab == .home ? 1 : 0)
            .allowsHitTesting(selectedTab == .home)

            GroupsScreen(onStartMatch: {
                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .home }
            })
            .opacity(selectedTab == .groups ? 1 : 0)
            .allowsHitTesting(selectedTab == .groups)

            FloatingTabBar(selection: $selectedTab)

            if let ctx = saveContext {
                CreateGroupSheet(
                    context: ctx,
                    groupsVM: groupsVM,
                    onDismiss: { saveContext = nil }
                )
                .zIndex(50)
            }
        }
        .environmentObject(groupsVM)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Floating tab bar

struct FloatingTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home, icon: "house", iconActive: "house.fill", label: L10n.tabHome)
            tabButton(.groups, icon: "folder", iconActive: "folder.fill", label: L10n.tabGroups)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(AppTheme.card.opacity(0.96)))
        .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 12)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func tabButton(
        _ tab: AppTab, icon: String, iconActive: String, label: String
    ) -> some View {
        let active = selection == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selection = tab }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: active ? iconActive : icon)
                    .font(.system(size: 18, weight: .medium))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(active ? .white : AppTheme.textMuted)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(active ? AppTheme.accentSoft : Color.clear))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
