import SwiftUI
import SwiftData

/// S5 – Quick Add from the "+" button on S1 (plan.md §4 S5):
/// sport (most recent preselected), opponent (most recent first), then S2b steps 2–4.
/// Also S8 "Add Match": then everyone in the match comes from the group (plan.md §4 S8).
struct QuickAddView: View {
    let me: Player
    let friends: [Player]
    /// S8: only these members, and the group's last sport is preselected.
    var group: PlayerGroup? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.onlineFriends) private var online
    @Environment(\.dismiss) private var dismiss
    @Query private var matches: [Match]

    @State private var selectedSport: Sport?
    @State private var selectedFriend: Player?
    @State private var path: [Sport] = []
    @State private var isCreatingSport = false
    @Query private var customSports: [CustomSport]
    @State private var isEdited = false
    @State private var isConfirmingDiscard = false
    @State private var didPreselect = false
    @AppStorage(SportSettings.favoritesKey) private var favoritesRaw = ""
    @AppStorage(SportSettings.hiddenKey) private var hiddenRaw = ""
    @AppStorage(SportSettings.hiddenCustomKey) private var hiddenCustomRaw = ""

    private var sports: [Sport] {
        SportSettings.entrySports(favorites: SportSettings.decode(favoritesRaw),
                                  hidden: SportSettings.decode(hiddenRaw),
                                  custom: customSports,
                                  hiddenCustom: SportSettings.decodeIDs(hiddenCustomRaw))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    Text("Choose a sport")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.rvTextPrimary)
                        .padding(.horizontal, Spacing.m)
                    SportGridView(sports: sports, selection: $selectedSport,
                                  onNewSport: { isCreatingSport = true })

                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text("Opponent")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.rvTextPrimary)
                        ForEach(QuickAdd.opponents(me: me, friends: friends, matches: matches)) { friend in
                            OpponentRow(friend: friend, isSelected: selectedFriend?.id == friend.id) {
                                selectedFriend = friend
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.m)
                }
                .padding(.vertical, Spacing.s)
            }
            .background(Color.rvBackground)
            .safeAreaInset(edge: .bottom) {
                Button("Continue") {
                    if let selectedSport { path = [selectedSport] }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedSport == nil || selectedFriend == nil)
                .padding(Spacing.m)
                .background(Color.rvBackground)
            }
            .navigationTitle("Add Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $isCreatingSport) {
                CustomSportFormView { selectedSport = Sport($0) }
            }
            .navigationDestination(for: Sport.self) { sport in
                if let friend = selectedFriend {
                    MatchEntryView(sport: sport, me: me, friend: friend, isEdited: $isEdited,
                                   pool: group?.opponents,
                                   onBack: backToStart,
                                   onSave: { save($0, against: friend) })
                }
            }
        }
        .tint(Color.rvAccent)
        .interactiveDismissDisabled(isEdited)
        .confirmationDialog("Discard match?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
            Button("Discard") { discard() }
            Button("Keep Editing", role: .cancel) {}
        }
        .onAppear {
            // Only once, so going back keeps your own choice.
            guard !didPreselect else { return }
            didPreselect = true
            selectedSport = QuickAdd.preselectedSport(me: me, matches: group?.matches(in: matches) ?? matches,
                                                      available: sports)
        }
    }

    /// Back to sport and opponent, asking "Discard match?" first if something was entered (plan.md §4 S2b).
    private func backToStart() {
        if isEdited {
            isConfirmingDiscard = true
        } else {
            discard()
        }
    }

    private func discard() {
        isEdited = false
        path = []
    }

    private func save(_ draft: MatchDraft, against friend: Player) {
        guard draft.isValid else { return }
        draft.insertMatch(me: me, friend: friend, into: context)
        // Online matches go up right away (Phase 3).
        Task { try? await online.syncMatches(me: me, context: context) }
        isEdited = false
        dismiss()
    }
}

/// One selectable friend; selected like a sport tile (design.md §2.2).
private struct OpponentRow: View {
    let friend: Player
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                AvatarView(player: friend)
                Text(friend.name)
                    .font(.body)
                    .foregroundStyle(Color.rvTextPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.rvAccent)
                }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s + Spacing.xs)
            .background(isSelected ? Color.rvAccentSoft : Color.rvSurface,
                        in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(Color.rvAccent, lineWidth: 2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

#Preview {
    let container = SampleData.container()
    let players = (try? container.mainContext.fetch(FetchDescriptor<Player>())) ?? []
    let me = players.first(where: \.isMe)!
    return QuickAddView(me: me, friends: players.filter { !$0.isMe })
        .modelContainer(container)
}
