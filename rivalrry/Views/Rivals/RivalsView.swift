import SwiftUI
import SwiftData

/// S1 – Rivals: where you stand against whom (plan.md §4 S1).
struct RivalsView: View {
    @Query(sort: \Player.createdAt) private var players: [Player]
    @Query private var matches: [Match]
    @Query private var groups: [PlayerGroup]
    @AppStorage("rivalsSort") private var sort: RivalsSort = .recentlyPlayed
    @State private var isAddingFriend = false
    @State private var isQuickAdding = false
    @State private var isAddingGroup = false

    private var me: Player? { players.first(where: \.isMe) }
    private var friends: [Player] { players.filter { !$0.isMe } }

    var body: some View {
        NavigationStack {
            Group {
                if friends.isEmpty {
                    EmptyStateView(symbol: "person.2",
                                   message: "No rivals yet. Add a friend to start keeping score.",
                                   buttonTitle: "Add Friend") {
                        isAddingFriend = true
                    }
                } else {
                    friendList
                }
            }
            .background(Color.rvBackground)
            .navigationTitle("Rivals")
            .toolbar { toolbar }
            .navigationDestination(for: Player.self) { friend in
                FriendDetailView(friend: friend)
            }
            .sheet(isPresented: $isAddingFriend) {
                AddFriendView()
            }
            .sheet(isPresented: $isAddingGroup) {
                GroupFormView()
            }
            .overlay(alignment: .bottomTrailing) { quickAddButton }
            .sheet(isPresented: $isQuickAdding) {
                if let me { QuickAddView(me: me, friends: friends) }
            }
        }
    }

    /// Floating "+" bottom right: Quick Add (plan.md §4 S5), green (design.md §2.2).
    @ViewBuilder
    private var quickAddButton: some View {
        if me != nil, friends.contains(where: { !$0.isArchived }) {
            Button {
                isQuickAdding = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.rvOnAccent)
                    .frame(width: 56, height: 56)
                    .background(Color.rvAccent, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .padding(Spacing.m)
            .accessibilityLabel("Add Match")
        }
    }

    private var friendList: some View {
        let active = Rivalry.summaries(of: me, friends: friends.filter { !$0.isArchived },
                                       matches: matches, sortedBy: sort)
        let archived = Rivalry.summaries(of: me, friends: friends.filter(\.isArchived),
                                         matches: matches, sortedBy: sort)
        return List {
            Section {
                ForEach(active) { summary in
                    row(summary, swipeTitle: "Archive", setArchived: true)
                }
            }
            groupSection
            if !archived.isEmpty {
                Section {
                    ForEach(archived) { summary in
                        row(summary, swipeTitle: "Restore", setArchived: false)
                    }
                } header: {
                    Text("Archived")
                        .font(.headline)
                        .foregroundStyle(Color.rvTextSecondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listRowSpacing(Spacing.s)
        // Room for the floating "+" button.
        .contentMargins(.bottom, 88, for: .scrollContent)
    }

    /// "Groups" below the friends (plan.md §4 S1, Phase 4), with "New Group" at the end.
    private var groupSection: some View {
        Section {
            ForEach(PlayerGroup.sorted(groups)) { group in
                GroupCard(group: group)
                    .listRowInsets(EdgeInsets(top: 0, leading: Spacing.m, bottom: 0, trailing: Spacing.m))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            newGroupButton
                .listRowInsets(EdgeInsets(top: 0, leading: Spacing.m, bottom: 0, trailing: Spacing.m))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        } header: {
            Text("Groups")
                .font(.headline)
                .foregroundStyle(Color.rvTextSecondary)
                .textCase(nil)
        }
    }

    private var newGroupButton: some View {
        Button {
            isAddingGroup = true
        } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: "plus")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Color.rvBackground, in: Circle())
                Text("New Group")
                    .font(.headline)
                Spacer()
            }
            .foregroundStyle(Color.rvTextPrimary)
            .padding(Spacing.m)
            .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func row(_ summary: FriendSummary, swipeTitle: String, setArchived: Bool) -> some View {
        FriendCard(summary: summary)
            // Invisible link hides the list's chevron: the whole card is tappable (design.md §6.2).
            .background(NavigationLink(value: summary.friend) { EmptyView() }.opacity(0))
            .listRowInsets(EdgeInsets(top: 0, leading: Spacing.m, bottom: 0, trailing: Spacing.m))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing) {
                Button(swipeTitle) {
                    withAnimation(.spring(duration: 0.3)) { summary.friend.isArchived = setArchived }
                }
                .tint(Color.rvTextSecondary)
            }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !friends.isEmpty {
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(RivalsSort.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundStyle(Color.rvTextPrimary)
                }
                .accessibilityLabel("Sort")
            }
            Button {
                isAddingFriend = true
            } label: {
                Image(systemName: "person.badge.plus")
                    .foregroundStyle(Color.rvTextPrimary)
            }
            .accessibilityLabel("Add Friend")
        }
    }
}

#Preview("4 friends") {
    RivalsView()
        .modelContainer(SampleData.container())
}

#Preview("Empty") {
    RivalsView()
        .modelContainer(SampleData.container(filled: false))
}
