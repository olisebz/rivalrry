import SwiftUI
import SwiftData

/// S8 – Group Detail (plan.md §4 S8): name, symbol, members and the group's recent matches.
/// "Edit Group" renames it and adds or removes members; "Leave Group" removes you for everyone.
/// The group ranking (step 6) and "Add Match" (step 4) follow.
struct GroupDetailView: View {
    let group: PlayerGroup

    @Query private var players: [Player]
    @Query private var allMatches: [Match]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.onlineBackend) private var backend

    @State private var isEditing = false
    @State private var isConfirmingLeave = false
    @State private var leaveOnDisappear = false

    private var me: Player? { players.first(where: \.isMe) }

    var body: some View {
        let matches = group.matches(in: allMatches)

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                header
                members
                if let me {
                    if matches.isEmpty {
                        EmptyStateView(symbol: "sportscourt", message: "No matches yet. Who's first?")
                    } else {
                        recentMatches(Array(matches.prefix(5)), me: me)
                    }
                }
            }
            .padding(.bottom, Spacing.l)
        }
        .background(Color.rvBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { menu }
        .navigationDestination(for: Match.self) { match in
            if let me { MatchDetailView(match: match, me: me) }
        }
        .sheet(isPresented: $isEditing) {
            GroupFormView(group: group)
        }
        .confirmationDialog("Leave \(group.name)?", isPresented: $isConfirmingLeave, titleVisibility: .visible) {
            Button("Leave Group", role: .destructive) {
                leaveOnDisappear = true
                dismiss()
            }
        } message: {
            Text("The group is removed for you. The other members keep it, and your matches stay.")
        }
        .onDisappear {
            // Leave after the screen is gone, so it never shows a deleted group.
            guard leaveOnDisappear, let me else { return }
            Task { try? await GroupSync.leave(group, me: me, context: context, backend: backend) }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: group.symbolName)
                .font(.system(size: 28))
                .foregroundStyle(Color.rvTextPrimary)
                .frame(width: 64, height: 64)
                .background(Color.rvSurface, in: Circle())
                .accessibilityHidden(true)
            Text(group.name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.rvTextPrimary)
                .multilineTextAlignment(.center)
            Text(group.memberCountText)
                .font(.subheadline)
                .foregroundStyle(Color.rvTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.s)
        .padding(.horizontal, Spacing.m)
    }

    private var members: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            sectionTitle("Members")
            VStack(spacing: 0) {
                ForEach(group.sortedMembers) { player in
                    HStack(spacing: Spacing.m) {
                        AvatarView(player: player, size: 32)
                        Text(player.isMe ? "You" : player.name)
                            .font(.body)
                            .foregroundStyle(Color.rvTextPrimary)
                        Spacer()
                    }
                    .padding(.vertical, Spacing.s)
                    if player.id != group.sortedMembers.last?.id || group.otherMembersText != nil {
                        Rectangle().fill(Color.rvSeparator).frame(height: 0.5)
                            .padding(.leading, 32 + Spacing.m)
                    }
                }
                if let others = group.otherMembersText {
                    // Members who aren't your friends (agreed with the user).
                    Text(others)
                        .font(.body)
                        .foregroundStyle(Color.rvTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Spacing.s + Spacing.xs)
                }
            }
            .padding(.horizontal, Spacing.m)
            .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .padding(.horizontal, Spacing.m)
    }

    private func recentMatches(_ matches: [Match], me: Player) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("Recent Matches")
                Spacer()
                NavigationLink("See all") {
                    GroupMatchListView(group: group, me: me)
                }
                .font(.headline)
                .foregroundStyle(Color.rvTextPrimary)
            }
            MatchRows(matches: matches, me: me)
        }
        .padding(.horizontal, Spacing.m)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title2.weight(.semibold))
            .foregroundStyle(Color.rvTextPrimary)
    }

    @ToolbarContentBuilder
    private var menu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Edit Group") { isEditing = true }
                Button("Leave Group", role: .destructive) { isConfirmingLeave = true }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Color.rvTextPrimary)
            }
            .accessibilityLabel("More")
        }
    }
}

/// "See all": every match of the group, filterable by sport.
struct GroupMatchListView: View {
    let group: PlayerGroup
    let me: Player
    @Query private var allMatches: [Match]
    @State private var sport: Sport?

    var body: some View {
        let all = group.matches(in: allMatches)
        let sports = Sport.byCount(in: all)
        let matches = all.filter { sport == nil || $0.sport == sport }

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if sports.count > 1 {
                    FilterChips(options: [(value: Sport?.none, title: "All")]
                                    + sports.map { (value: Sport?.some($0), title: $0.displayName) },
                                selection: $sport)
                }
                MatchRows(matches: matches, me: me)
                    .padding(.horizontal, Spacing.m)
            }
            .padding(.top, Spacing.s)
        }
        .background(Color.rvBackground)
        .navigationTitle("Matches")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Padel group") {
    let container = SampleData.container()
    let group = (try? container.mainContext.fetch(FetchDescriptor<PlayerGroup>()))?.first
    return NavigationStack {
        if let group { GroupDetailView(group: group) }
    }
    .modelContainer(container)
}
