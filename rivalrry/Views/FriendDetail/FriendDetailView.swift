import SwiftUI
import SwiftData

/// S2 – Friend Detail (plan.md §4 S2, decisions 1 and 2).
struct FriendDetailView: View {
    let friend: Player

    @Query private var players: [Player]
    @Query private var allMatches: [Match]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var tab: DetailTab = .overview
    @State private var isAddingMatch = false
    @State private var isEditingFriend = false
    @State private var isConfirmingDelete = false
    @State private var deleteOnDisappear = false
    @State private var savedCount = 0
    @State private var showsSavedMessage = false

    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case stats = "Stats"
    }

    private var me: Player? { players.first(where: \.isMe) }

    var body: some View {
        let matches = me.map { Rivalry.matches(of: $0, with: friend, in: allMatches) } ?? []
        let record = me.map { Rivalry.record(of: $0, against: friend, in: allMatches) } ?? Record()

        ScrollView {
            VStack(spacing: Spacing.l) {
                FriendHeaderView(me: me, friend: friend, record: record)

                Picker("View", selection: $tab) {
                    ForEach(DetailTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.m)

                switch tab {
                case .overview:
                    if let me, !matches.isEmpty {
                        OverviewView(me: me, friend: friend, matches: matches)
                    } else {
                        EmptyStateView(symbol: "sportscourt",
                                       message: "No matches yet. Who's first?",
                                       buttonTitle: "Add Match") {
                            isAddingMatch = true
                        }
                    }
                case .stats:
                    if let me {
                        StatsView(me: me, friend: friend, allMatches: allMatches)
                    } else {
                        EmptyStateView(symbol: "chart.xyaxis.line", message: "Play a few matches to see stats.")
                    }
                }
            }
            .padding(.bottom, Spacing.l)
        }
        .background(Color.rvBackground)
        .safeAreaInset(edge: .bottom) {
            // Only one primary button per screen: the empty state brings its own.
            if tab == .overview, !matches.isEmpty {
                Button("Add Match") { isAddingMatch = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(Color.rvBackground)
            }
        }
        .navigationTitle(tab == .stats ? friend.shortName : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { menu }
        .navigationDestination(for: Match.self) { match in
            if let me {
                MatchDetailView(match: match, me: me)
            }
        }
        .sheet(isPresented: $isAddingMatch) {
            AddMatchView(me: me, friend: friend) {
                tab = .overview
                savedCount += 1
            }
        }
        .overlay(alignment: .bottom) {
            if showsSavedMessage {
                Text("Match saved")
                    .font(.headline)
                    .foregroundStyle(Color.rvTextPrimary)
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.s + Spacing.xs)
                    .background(Color.rvSurface, in: Capsule())
                    .padding(.bottom, 88)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.success, trigger: savedCount)
        .task(id: savedCount) {
            // Short confirmation after saving (plan.md §4 S2b).
            guard savedCount > 0 else { return }
            withAnimation(.spring(duration: 0.3)) { showsSavedMessage = true }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.spring(duration: 0.3)) { showsSavedMessage = false }
        }
        .sheet(isPresented: $isEditingFriend) {
            FriendFormView(friend: friend)
        }
        .confirmationDialog("Delete \(friend.shortName)?", isPresented: $isConfirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete Friend", role: .destructive) {
                deleteOnDisappear = true
                dismiss()
            }
        } message: {
            Text("Matches only between you and \(friend.shortName) will be deleted. "
                 + "Other matches keep \(friend.shortName) as \"Deleted Player\".")
        }
        .onDisappear {
            // Delete after leaving the screen, so it never shows a deleted friend.
            if deleteOnDisappear { Rivalry.delete(friend, in: context) }
        }
    }

    @ToolbarContentBuilder
    private var menu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Edit Friend") { isEditingFriend = true }
                Button(friend.isArchived ? "Restore" : "Archive") {
                    friend.isArchived.toggle()
                    if friend.isArchived { dismiss() }
                }
                Button("Delete Friend", role: .destructive) { isConfirmingDelete = true }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Color.rvTextPrimary)
            }
            .accessibilityLabel("More")
        }
    }
}

#Preview("Max – you lead") {
    let container = SampleData.container()
    return NavigationStack {
        FriendDetailView(friend: SampleData.player("Max Keller", in: container))
    }
    .modelContainer(container)
}

#Preview("Tom – friend leads") {
    let container = SampleData.container()
    return NavigationStack {
        FriendDetailView(friend: SampleData.player("Tom Berger", in: container))
    }
    .modelContainer(container)
}

#Preview("No matches") {
    let container = SampleData.container()
    let newFriend = Player(name: "Sara Lind", colorHex: "0CA678")
    container.mainContext.insert(newFriend)
    return NavigationStack {
        FriendDetailView(friend: newFriend)
    }
    .modelContainer(container)
}

#Preview("Max – Stats") {
    let container = SampleData.container()
    return NavigationStack {
        StatsPreviewHost(friend: SampleData.player("Max Keller", in: container),
                         me: SampleData.player("Alex Morgan", in: container))
    }
    .modelContainer(container)
}

#if DEBUG
/// Shows only the Stats tab in a preview.
private struct StatsPreviewHost: View {
    let friend: Player
    let me: Player
    @Query private var matches: [Match]

    var body: some View {
        ScrollView {
            StatsView(me: me, friend: friend, allMatches: matches)
        }
        .background(Color.rvBackground)
    }
}
#endif
