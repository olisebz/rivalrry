import SwiftUI
import SwiftData

/// S3 – Match Detail: the full result, "Edit" and "Delete" (plan.md §4 S3, Phase 1–2).
struct MatchDetailView: View {
    let match: Match
    let me: Player

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var isEdited = false
    @State private var isConfirmingDelete = false
    @State private var deleteOnDisappear = false

    private var sideA: MatchParticipant? { match.participants(on: .a).first }
    private var sideB: MatchParticipant? { match.participants(on: .b).first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                heading
                scoreboard
                details
                if let note = match.note, !note.isEmpty {
                    section("Note") {
                        Text(note)
                            .font(.body)
                            .foregroundStyle(Color.rvTextPrimary)
                    }
                }
                Button("Delete Match", role: .destructive) { isConfirmingDelete = true }
                    .font(.headline)
                    .foregroundStyle(Color.rvDestructive)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(Spacing.m)
        }
        .background(Color.rvBackground)
        .navigationTitle(match.customSport?.name ?? match.sportType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditing = true }
                    .disabled(!canEdit)
            }
        }
        .sheet(isPresented: $isEditing) { editSheet }
        .confirmationDialog("Delete match?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Match", role: .destructive) {
                deleteOnDisappear = true
                dismiss()
            }
        } message: {
            Text("This can't be undone.")
        }
        .onDisappear {
            // Delete after leaving the screen, so it never shows a deleted match.
            if deleteOnDisappear { context.delete(match) }
        }
    }

    /// Phase 1 can only edit 1v1 matches of the Phase 1 sports.
    private var canEdit: Bool {
        match.mode == .oneVsOne && SportType.phase1Sports.contains(match.sportType)
    }

    // MARK: - Heading

    private var heading: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: match.customSport?.symbolName ?? match.sportType.symbolName)
                .font(.system(size: 28))
                .foregroundStyle(Color.rvTextPrimary)
                .frame(width: 44, height: 44)
                .background(Color.rvSurface, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(match.customSport?.name ?? match.sportType.displayName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.rvTextPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.rvTextSecondary)
            }
        }
    }

    /// "1v1 · Nov 12, 2026 at 6:30 PM"
    private var subtitle: String {
        let mode = switch match.mode {
        case .oneVsOne: "1v1"
        case .team: "Team"
        case .race: "Race"
        }
        let date = match.date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened)
            .locale(Locale(identifier: "en_US")))
        return "\(mode) · \(date)"
    }

    // MARK: - Scoreboard

    /// Both players, the result in the middle, winner marked in green.
    private var scoreboard: some View {
        let winner: Side? = if case .win(let side) = match.result?.outcome { side } else { nil }
        let isDraw = match.result?.outcome == .draw

        return VStack(spacing: Spacing.m) {
            HStack(alignment: .top) {
                player(sideA, isWinner: winner == .a)
                Spacer()
                player(sideB, isWinner: winner == .b)
            }
            Text(match.scoreText(for: me))
                .font(.rvScoreLarge)
                .foregroundStyle(match.outcome(for: me) == .win ? Color.rvAccent : Color.rvTextPrimary)
            if isDraw {
                Text("Draw")
                    .font(.headline)
                    .foregroundStyle(Color.rvTextSecondary)
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func player(_ participant: MatchParticipant?, isWinner: Bool) -> some View {
        let player = participant?.player
        let label = player.map { $0.isMe ? "You" : $0.shortName } ?? "Deleted Player"
        return VStack(spacing: Spacing.s) {
            AvatarView(name: player?.name ?? "?", colorHex: player?.colorHex ?? "6E6E73",
                       photo: player?.photo, size: 64)
            Text(label)
                .font(.headline)
                .foregroundStyle(isWinner ? Color.rvAccent : Color.rvTextPrimary)
                .lineLimit(1)
            Text(isWinner ? "Winner" : " ")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.rvAccent)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, 2)
                .background(isWinner ? Color.rvAccentSoft : .clear, in: Capsule())
        }
        .frame(minWidth: 96)
    }

    // MARK: - Details per scoring type

    @ViewBuilder
    private var details: some View {
        switch match.scoringType {
        case .sets: setsDetails
        case .penalties: penaltyDetails
        case .fight: fightDetails
        case .time: timeDetails
        case .points, .placement, .winLoss: EmptyView()
        }
    }

    private var setsDetails: some View {
        section(match.bestOf.map { "Best of \($0)" } ?? "Sets") {
            VStack(spacing: 0) {
                ForEach(match.orderedSets) { set in
                    HStack {
                        Text("Set \(set.index + 1)")
                            .foregroundStyle(Color.rvTextSecondary)
                        Spacer()
                        if let a = set.tiebreakA, let b = set.tiebreakB {
                            Text("(\(a)–\(b))")
                                .foregroundStyle(Color.rvTextSecondary)
                        }
                        Text("\(set.scoreA) – \(set.scoreB)")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.rvTextPrimary)
                    }
                    .font(.body.monospacedDigit())
                    .padding(.vertical, Spacing.s + Spacing.xs)
                    Rectangle().fill(Color.rvSeparator).frame(height: 0.5)
                }
                if let retired = match.retiredSide {
                    Text("Match not finished: \(name(of: retired)) gave up")
                        .font(.subheadline)
                        .foregroundStyle(Color.rvTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Spacing.s)
                }
            }
        }
    }

    private var penaltyDetails: some View {
        let shots = match.orderedPenalties
        let rounds = (shots.count + 1) / 2
        let regular = match.penaltyShotsPerSide ?? rounds

        return section("\(regular) shots") {
            VStack(alignment: .leading, spacing: Spacing.s) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Grid(alignment: .leading, horizontalSpacing: Spacing.xs, verticalSpacing: Spacing.s) {
                        ForEach([Side.a, .b], id: \.self) { side in
                            GridRow {
                                Text(name(of: side))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.rvTextPrimary)
                                    .frame(width: 64, alignment: .leading)
                                ForEach(0..<rounds, id: \.self) { round in
                                    let index = round * 2 + (side == .a ? 0 : 1)
                                    ShotCircle(state: index < shots.count ? (shots[index].scored ? .scored : .missed) : .empty)
                                }
                            }
                        }
                    }
                }
                if shots.contains(where: \.isSuddenDeath) {
                    Text("Sudden Death")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rvTextSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var fightDetails: some View {
        if let fight = match.fight {
            section("Fight") {
                VStack(spacing: 0) {
                    detailRow("Method", fight.method.displayName)
                    detailRow("Rounds", "\(fight.totalRounds)")
                    if let endRound = fight.endRound {
                        detailRow("Ended in round", "\(endRound)")
                    }
                }
            }
        }
    }

    private var timeDetails: some View {
        section(match.distanceMeters.map { TimeText.distance($0) } ?? "Running") {
            VStack(spacing: 0) {
                detailRow(name(of: .a), TimeText.text(for: sideA))
                detailRow(name(of: .b), TimeText.text(for: sideB))
            }
        }
    }

    // MARK: - Helpers

    private func name(of side: Side) -> String {
        let participant = side == .a ? sideA : sideB
        guard let player = participant?.player else { return "Deleted Player" }
        return player.isMe ? "You" : player.shortName
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.rvTextPrimary)
            content()
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).foregroundStyle(Color.rvTextSecondary)
                Spacer()
                Text(value)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.rvTextPrimary)
                    .monospacedDigit()
            }
            .font(.body)
            .padding(.vertical, Spacing.s + Spacing.xs)
            Rectangle().fill(Color.rvSeparator).frame(height: 0.5)
        }
    }

    // MARK: - Edit

    @ViewBuilder
    private var editSheet: some View {
        if let friend = sideB?.player ?? sideA?.player {
            NavigationStack {
                MatchEntryView(sport: match.sportType, me: me, friend: friend, isEdited: $isEdited,
                               initialDraft: MatchDraft(match: match),
                               onCancel: { isEditing = false }) { draft in
                    guard draft.isValid else { return }
                    draft.apply(to: match, context: context)
                    isEdited = false
                    isEditing = false
                }
            }
            .tint(Color.rvAccent)
            .interactiveDismissDisabled(isEdited)
        }
    }
}

#Preview("Badminton") {
    let container = SampleData.container()
    let me = SampleData.player("Alex Morgan", in: container)
    let max = SampleData.player("Max Keller", in: container)
    let match = Rivalry.matches(of: me, with: max, in: (try? container.mainContext.fetch(FetchDescriptor<Match>())) ?? [])
        .first { $0.sportType == .badminton }!
    match.note = "Close one in the third set."
    return NavigationStack {
        MatchDetailView(match: match, me: me)
    }
    .modelContainer(container)
}

#Preview("Penalty Shootout") {
    let container = SampleData.container()
    let me = SampleData.player("Alex Morgan", in: container)
    let max = SampleData.player("Max Keller", in: container)
    let match = Rivalry.matches(of: me, with: max, in: (try? container.mainContext.fetch(FetchDescriptor<Match>())) ?? [])
        .first { $0.sportType == .penaltyShootout }!
    return NavigationStack {
        MatchDetailView(match: match, me: me)
    }
    .modelContainer(container)
}
