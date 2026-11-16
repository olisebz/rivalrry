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

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    EntryHeading(title: "Choose a sport", friendName: friend.shortName)
                        .padding(.horizontal, Spacing.m)
                    SportGridView(selection: $selectedSport)
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
struct MatchEntryView: View {
    let sport: SportType
    let me: Player?
    let friend: Player
    @Binding var isEdited: Bool
    let onBack: () -> Void
    let onSave: (MatchDraft) -> Void

    @State private var draft: MatchDraft
    @State private var showsDetails = false

    init(sport: SportType, me: Player?, friend: Player, isEdited: Binding<Bool>,
         onBack: @escaping () -> Void, onSave: @escaping (MatchDraft) -> Void) {
        self.sport = sport
        self.me = me
        self.friend = friend
        self._isEdited = isEdited
        self.onBack = onBack
        self.onSave = onSave
        self._draft = State(initialValue: MatchDraft(sport: sport))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                EntryHeading(title: sport.displayName, friendName: friend.shortName)

                switch sport.scoringType {
                case .sets: SetsEntryView(draft: $draft, friendName: friend.shortName)
                case .points: PointsEntryView(draft: $draft, friendName: friend.shortName)
                case .penalties: PenaltiesEntryView(draft: $draft, friendName: friend.shortName)
                case .fight: FightEntryView(draft: $draft, friendName: friend.shortName)
                case .time: TimeEntryView(draft: $draft, friendName: friend.shortName)
                case .placement, .winLoss: EmptyView()
                }

                moreDetails
            }
            .padding(Spacing.m)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.rvBackground)
        .safeAreaInset(edge: .bottom) { saveArea }
        .navigationTitle("Add Match")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
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
