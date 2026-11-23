import SwiftUI
import SwiftData

/// Onboarding on first launch, then the tab bar: "Rivals", "Requests" (Phase 3), "Profile" (plan.md §3).
struct RootView: View {
    @AppStorage(SportSettings.onboardedKey) private var isOnboarded = false
    @Query private var players: [Player]
    @Query private var matches: [Match]
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.onlineFriends) private var online
    /// Username from an opened invite link (`rivalrry://invite/<username>`).
    @State private var invitation: Invitation?

    /// Friend requests plus matches and deletion requests you need to answer.
    private var badgeCount: Int {
        let matchActions = players.first(where: \.isMe).map { MatchRequests(matches: matches, me: $0).actionCount } ?? 0
        return online.incoming.count + matchActions
    }

    var body: some View {
        if isOnboarded {
            TabView {
                RivalsView()
                    .tabItem { Label("Rivals", systemImage: "person.2") }
                RequestsView()
                    .tabItem { Label("Requests", systemImage: "tray") }
                    // Badge = things you need to handle (plan.md §4 S6).
                    .badge(badgeCount)
                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            }
            // Active tab and system controls in accent green (design.md §2.2).
            .tint(Color.rvAccent)
            .onOpenURL { url in invitation = Invite.username(from: url).map(Invitation.init) }
            .sheet(item: $invitation) { InviteSheet(username: $0.username) }
            .task(id: scenePhase) {
                guard scenePhase == .active, let me = players.first(where: \.isMe) else { return }
                try? await online.syncAll(me: me, context: context)
            }
        } else {
            OnboardingView()
        }
    }
}

#Preview("With data") {
    RootView()
        .modelContainer(SampleData.container())
        .defaultAppStorage(onboardedDefaults)
}

#Preview("Empty") {
    RootView()
        .modelContainer(SampleData.container(filled: false))
        .defaultAppStorage(onboardedDefaults)
}

/// The username from an opened invite link, as a sheet item.
private struct Invitation: Identifiable {
    let username: String
    var id: String { username }
}

#if DEBUG
/// Previews skip onboarding.
private let onboardedDefaults: UserDefaults = {
    let defaults = UserDefaults(suiteName: "preview.onboarded")!
    defaults.set(true, forKey: SportSettings.onboardedKey)
    return defaults
}()
#endif
