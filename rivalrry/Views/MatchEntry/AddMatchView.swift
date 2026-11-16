import SwiftUI
import SwiftData

/// S2b – Add Match, as a sheet from S2 (decision 1). Step 1: sport, then the result.
/// Phase 1 is 1v1 only, so the mode step is skipped (plan.md §4 S2b).
struct AddMatchView: View {
    let me: Player?
    let friend: Player
    let onSaved: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSport: SportType?
    @State private var path: [SportType] = []
    @State private var isEdited = false
    @State private var isConfirmingDiscard = false
    @AppStorage(SportSettings.favoritesKey) private var favoritesRaw = ""
    @AppStorage(SportSettings.hiddenKey) private var hiddenRaw = ""

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    EntryHeading(title: "Choose a sport", friendName: friend.shortName)
                        .padding(.horizontal, Spacing.m)
                    SportGridView(sports: SportSettings.entrySports(favorites: SportSettings.decode(favoritesRaw),
                                                                    hidden: SportSettings.decode(hiddenRaw)),
                                  selection: $selectedSport)
                }
                .padding(.top, Spacing.s)
            }
            .background(Color.rvBackground)
            .safeAreaInset(edge: .bottom) {
                Button("Continue") {
                    if let selectedSport { path = [selectedSport] }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedSport == nil)
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
            .navigationDestination(for: SportType.self) { sport in
                MatchEntryView(sport: sport, me: me, friend: friend, isEdited: $isEdited,
                               onBack: backToSports,
                               onSave: save)
            }
        }
        .tint(Color.rvAccent)
        .interactiveDismissDisabled(isEdited)
        .confirmationDialog("Discard match?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
            Button("Discard") { discard() }
            Button("Keep Editing", role: .cancel) {}
        }
    }

    /// Back to the sport grid. Asks "Discard match?" first if something was entered (plan.md §4 S2b).
    private func backToSports() {
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

    private func save(_ draft: MatchDraft) {
        guard let me, draft.isValid else { return }
        draft.insertMatch(me: me, friend: friend, into: context)
        isEdited = false
        onSaved()
        dismiss()
    }
}

/// "Badminton" / "vs Max" heading at the top of each S2b step.
struct EntryHeading: View {
    let title: String
    let friendName: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.rvTextPrimary)
            Text("vs \(friendName)")
                .font(.subheadline)
                .foregroundStyle(Color.rvTextSecondary)
        }
    }
}

/// S2b steps 3–4: result for the chosen sport, "More details", live preview and "Save Match".
/// Also used for S3 "Edit": then it starts with the saved match and shows "Cancel" instead of "‹ Sport".
struct MatchEntryView: View {
    let sport: SportType
    let me: Player?
    let friend: Player
    @Binding var isEdited: Bool
    /// "‹ Sport" when adding; `nil` when editing.
    let onBack: (() -> Void)?
    let onCancel: (() -> Void)?
    let onSave: (MatchDraft) -> Void

    @State private var draft: MatchDraft
    @State private var showsDetails = false
    @Query private var players: [Player]

    init(sport: SportType, me: Player?, friend: Player, isEdited: Binding<Bool>,
         initialDraft: MatchDraft? = nil,
         onBack: (() -> Void)? = nil, onCancel: (() -> Void)? = nil,
         onSave: @escaping (MatchDraft) -> Void) {
        self.sport = sport
        self.me = me
        self.friend = friend
        self._isEdited = isEdited
        self.onBack = onBack
        self.onCancel = onCancel
        self.onSave = onSave
        // Default format from S9 "Sports" (plan.md §4 S9).
        var start = initialDraft ?? MatchDraft(sport: sport, bestOf: SportSettings.defaultBestOf(for: sport))
        // Go-Kart starts with you and the friend on the grid.
        if let me { start.setUpRace(me: me, friend: friend) }
        self._draft = State(initialValue: start)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                EntryHeading(title: sport.displayName, friendName: friend.shortName)

                // Mode & participants, only for sports with a team mode (plan.md §2.1).
                if draft.allowsTeams, !draft.teamsLocked {
                    TeamEditorView(draft: $draft, me: me, friend: friend, players: players)
                }

                let names = draft.names(friendName: friend.shortName)
                switch sport.scoringType {
                case .sets: SetsEntryView(draft: $draft, friendName: names.b, myName: names.a)
                case .points: PointsEntryView(draft: $draft, friendName: names.b, myName: names.a)
                case .penalties: PenaltiesEntryView(draft: $draft, friendName: names.b, myName: names.a)
                case .fight: FightEntryView(draft: $draft, friendName: names.b, myName: names.a)
                case .time:
                    TimeEntryView(draft: $draft, friendName: names.b, myName: names.a,
                                  available: draft.availablePlayers(from: players, friend: friend))
                case .placement:
                    RaceEntryView(draft: $draft, friend: friend,
                                  available: draft.availablePlayers(from: players, friend: friend))
                case .winLoss: EmptyView()
                }

                moreDetails
            }
            .padding(Spacing.m)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.rvBackground)
        .safeAreaInset(edge: .bottom) { saveArea }
        .navigationTitle(onBack == nil ? "Edit Match" : "Add Match")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if let onCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            if let onBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onBack) {
                        // Icon + text: toolbars would otherwise show only the icon.
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "chevron.left")
                                .fontWeight(.semibold)
                            Text("Sport")
                        }
                        .padding(.horizontal, Spacing.xs)
                    }
                    .accessibilityLabel("Sport")
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }
            }
        }
        .onChange(of: draft) { isEdited = true }

    }

    // MARK: - More details

    private var moreDetails: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Rectangle().fill(Color.rvSeparator).frame(height: 0.5)

            Button {
                withAnimation(.spring(duration: 0.3)) { showsDetails.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("More details")
                            .font(.body)
                            .foregroundStyle(Color.rvTextPrimary)
                        Text("Date, note")
                            .font(.subheadline)
                            .foregroundStyle(Color.rvTextSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rvTextSecondary)
                        .rotationEffect(.degrees(showsDetails ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsDetails {
                // No future dates (plan.md §4 S2b).
                DatePicker("Date", selection: $draft.date, in: ...Date(),
                           displayedComponents: [.date, .hourAndMinute])
                    .tint(Color.rvAccent)
                TextField("Note", text: $draft.note, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(Spacing.m)
                    .background(Color.rvSurface,
                                in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                    .onChange(of: draft.note) { _, note in
                        if note.count > MatchDraft.noteLimit { draft.note = String(note.prefix(MatchDraft.noteLimit)) }
                    }
            }
        }
    }

    // MARK: - Save

    private var saveArea: some View {
        let result = draft.validate()
        let isValid = (try? result.get()) != nil

        return VStack(spacing: Spacing.s) {
            if let preview = draft.previewText(friendName: friend.shortName) {
                Text(preview)
                    .font(.headline)
                    .foregroundStyle(youWin(result) ? Color.rvAccent : Color.rvTextPrimary)
                    .contentTransition(.numericText())
            } else if isEdited, case .failure(let issue) = result {
                // Only explain once something was entered, not on an untouched form.
                Label(issue.message, systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color.rvTextSecondary)
                    .multilineTextAlignment(.center)
            }
            Button("Save Match") { onSave(draft) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isValid || me == nil)
        }
        .padding(Spacing.m)
        .background(Color.rvBackground)
        .animation(.spring(duration: 0.3), value: draft)
    }

    private func youWin(_ result: Result<MatchResult, ResultIssue>) -> Bool {
        if case .success(let value) = result, value.outcome == .win(.a) { return true }
        return false
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview("Choose a sport") {
    let container = SampleData.container()
    return AddMatchView(me: SampleData.player("Alex Morgan", in: container),
                        friend: SampleData.player("Max Keller", in: container)) {}
        .modelContainer(container)
}

#Preview("Badminton") {
    let container = SampleData.container()
    return NavigationStack {
        MatchEntryView(sport: .badminton, me: SampleData.player("Alex Morgan", in: container),
                       friend: SampleData.player("Max Keller", in: container),
                       isEdited: .constant(false), onBack: {}, onSave: { _ in })
    }
    .modelContainer(container)
}

#Preview("Penalty Shootout") {
    let container = SampleData.container()
    return NavigationStack {
        MatchEntryView(sport: .penaltyShootout, me: SampleData.player("Alex Morgan", in: container),
                       friend: SampleData.player("Max Keller", in: container),
                       isEdited: .constant(false), onBack: {}, onSave: { _ in })
    }
    .modelContainer(container)
}

#Preview("Padel doubles") {
    let container = SampleData.container()
    var draft = MatchDraft(sport: .padel)
    draft.mode = .team
    draft.partners = [SampleData.player("Tom Berger", in: container)]
    draft.opponents = [SampleData.player("Lukas Huber", in: container)]
    draft.sets = [SetEntry(scoreA: 6, scoreB: 4)]
    return NavigationStack {
        MatchEntryView(sport: .padel, me: SampleData.player("Alex Morgan", in: container),
                       friend: SampleData.player("Max Keller", in: container),
                       isEdited: .constant(true), initialDraft: draft, onBack: {}, onSave: { _ in })
    }
    .modelContainer(container)
}

#Preview("Go-Kart") {
    let container = SampleData.container()
    let me = SampleData.player("Alex Morgan", in: container)
    let max = SampleData.player("Max Keller", in: container)
    var draft = MatchDraft(sport: .goKart)
    draft.racers = [RaceEntry(player: max, lapText: "1:01.870"), RaceEntry(player: me, lapText: "1:02.345"),
                    RaceEntry(player: SampleData.player("Tom Berger", in: container)),
                    RaceEntry(player: SampleData.player("Lukas Huber", in: container), dnf: true)]
    return NavigationStack {
        MatchEntryView(sport: .goKart, me: me, friend: max,
                       isEdited: .constant(true), initialDraft: draft, onBack: {}, onSave: { _ in })
    }
    .modelContainer(container)
}
