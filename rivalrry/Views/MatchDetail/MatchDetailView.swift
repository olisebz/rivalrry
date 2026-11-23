import SwiftUI
import SwiftData

/// S3 – Match Detail: the full result, status banner (Phase 3), "Edit" and "Delete" (plan.md §4 S3).
struct MatchDetailView: View {
    let match: Match
    let me: Player
    /// The friend whose page this was opened from. In team matches, side B has several players.
    var friend: Player? = nil

    @Environment(\.modelContext) private var context
    /// Elo is computed from all matches (plan.md §2.4).
    @Query private var allMatches: [Match]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.onlineFriends) private var online
    @State private var isEditing = false
    @State private var isEdited = false
    @State private var isConfirmingDelete = false
    @State private var deleteOnDisappear = false
    @State private var isConfirmingDeletionRequest = false
    @State private var errorMessage: String?

    // SwiftData doesn't keep the order of participants: pick you on side A and the friend on side B.
    private var sideA: MatchParticipant? {
        let side = match.participants(on: .a)
        return side.first { $0.player?.isMe == true } ?? side.first
    }
    private var sideB: MatchParticipant? {
        let side = match.participants(on: .b)
        return side.first { $0.player?.id == friend?.id } ?? side.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                heading
                statusBanner
                scoreboard
                details
                eloChanges
                if let note = match.note, !note.isEmpty {
                    section("Note") {
                        Text(note)
                            .font(.body)
                            .foregroundStyle(Color.rvTextPrimary)
                    }
                }
                if match.canDelete(by: me) {
                    Button("Delete Match", role: .destructive) { isConfirmingDelete = true }
                        .font(.headline)
                        .foregroundStyle(Color.rvDestructive)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else if match.canRequestDeletion(by: me) {
                    // Confirmed matches: only if everyone agrees (plan.md §4 S3).
                    Button("Request deletion", role: .destructive) { isConfirmingDeletionRequest = true }
                        .font(.headline)
                        .foregroundStyle(Color.rvDestructive)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(Spacing.m)
        }
        .background(Color.rvBackground)
        .navigationTitle(match.sport.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if match.canEdit(by: me) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { isEditing = true }
                        .disabled(!canEdit)
                }
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
        .confirmationDialog("Request deletion?", isPresented: $isConfirmingDeletionRequest,
                            titleVisibility: .visible) {
            Button("Request deletion", role: .destructive) { run { try await MatchSync.requestDeletion(match, me: me, backend: $0) } }
        } message: {
            Text("The match is deleted once everyone agrees.")
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onDisappear {
            // Delete after leaving the screen, so it never shows a deleted match.
            guard deleteOnDisappear else { return }
            // Your online match disappears for the others too.
            if match.status != .local {
                let id = match.id
                let backend = online.backend
                Task { try? await MatchSync.deleteOnline(matchID: id, backend: backend) }
            }
            context.delete(match)
        }
    }

    /// 1v1 and team matches of the supported sports can be edited, if no player was deleted.
    /// In team matches only the result changes, the teams stay as they are.
    private var canEdit: Bool {
        match.mode != .race && (match.sport.isCustom || SportType.phase1Sports.contains(match.sportType))
            && !match.participants.isEmpty && match.participants.allSatisfy { $0.player != nil }
    }

    // MARK: - Status

    /// "Waiting for Max to confirm", "Confirmed", "Rejected by Max: …" (plan.md §4 S3), plus an open change
    /// or deletion request and "Remind". Neutral colors: red is only for deleting (decision 5).
    @ViewBuilder
    private var statusBanner: some View {
        if let text = match.statusText {
            VStack(alignment: .leading, spacing: Spacing.s) {
                statusLine(text, symbol: statusSymbol)
                if let changeText = match.changeText {
                    statusLine(changeText, symbol: "pencil")
                    if let score = match.changeScoreText(for: me) {
                        Text("New result: \(score)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Color.rvTextSecondary)
                            .padding(.leading, 28)
                    }
                }
                if let deletionText = match.deletionText(me: me) {
                    statusLine(deletionText, symbol: "trash")
                }
                remindRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.m)
            .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
    }

    private func statusLine(_ text: String, symbol: String) -> some View {
        Label {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.rvTextPrimary)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(Color.rvTextSecondary)
        }
    }

    /// "Remind" once every 24 h while your match waits (plan.md §4 S3).
    @ViewBuilder
    private var remindRow: some View {
        if match.createdBy?.id == me.id, match.isWaitingForOthers {
            if match.canRemind(by: me) {
                Button("Remind") {
                    MatchSync.remind(match, me: me)
                    run { _ in try await online.syncMatches(me: me, context: context) }
                }
                .buttonStyle(PillButtonStyle())
            } else if let remindedAt = match.remindedAt {
                Text(RemindText.text(for: remindedAt))
                    .font(.subheadline)
                    .foregroundStyle(Color.rvTextSecondary)
            }
        }
    }

    /// Runs an online action, then syncs; shows an alert if it fails.
    private func run(_ action: @escaping (any OnlineBackend) async throws -> Void) {
        let backend = online.backend
        Task {
            do {
                try await action(backend)
                try await online.syncMatches(me: me, context: context)
            } catch {
                errorMessage = "Check your internet connection and try again."
            }
        }
    }

    private var statusSymbol: String {
        switch match.status {
        case .confirmed: "checkmark"
        case .rejected: "xmark"
        case .pending, .local: "clock"
        }
    }

    // MARK: - Heading

    private var heading: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: match.sport.symbolName)
                .font(.system(size: 28))
                .foregroundStyle(Color.rvTextPrimary)
                .frame(width: 44, height: 44)
                .background(Color.rvSurface, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(match.sport.displayName)
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
        case .team: match.teamFormat
        case .race: "Race"
        }
        let date = match.date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened)
            .locale(Locale(identifier: "en_US")))
        return "\(mode) · \(date)"
    }

    // MARK: - Scoreboard

    /// Both players, the result in the middle, winner marked in green.
    @ViewBuilder
    private var scoreboard: some View {
        if match.mode == .race { raceBoard } else { duelBoard }
    }

    private var duelBoard: some View {
        let winner: Side? = if case .win(let side) = match.result?.outcome { side } else { nil }
        let isDraw = match.result?.outcome == .draw

        return VStack(spacing: Spacing.m) {
            HStack(alignment: .top) {
                if match.mode == .team {
                    team(.a, isWinner: winner == .a)
                    Spacer()
                    team(.b, isWinner: winner == .b)
                } else {
                    player(sideA, isWinner: winner == .a)
                    Spacer()
                    player(sideB, isWinner: winner == .b)
                }
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

    /// Race result: your place, then everyone in finishing order (plan.md §4 S3).
    private var raceBoard: some View {
        VStack(spacing: Spacing.m) {
            Text(match.scoreText(for: me))
                .font(.rvScoreLarge)
                .foregroundStyle(match.outcome(for: me) == .win ? Color.rvAccent : Color.rvTextPrimary)

            VStack(spacing: 0) {
                ForEach(Array(match.raceOrder.enumerated()), id: \.offset) { index, participant in
                    raceRow(participant)
                    if index < match.raceOrder.count - 1 {
                        Rectangle().fill(Color.rvSeparator).frame(height: 0.5)
                    }
                }
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func raceRow(_ participant: MatchParticipant) -> some View {
        let place = match.racePlace(of: participant)
        let player = participant.player
        let name = player.map { $0.isMe ? "You" : $0.shortName } ?? "Deleted Player"
        // Running: the time; Go-Kart: the fastest lap, if entered.
        let detail: String? = match.scoringType == .time
            ? TimeText.text(for: participant)
            : participant.fastestLapMs.map { "Best lap \(TimeText.lap(milliseconds: $0))" }

        return HStack(spacing: Spacing.m) {
            Text(place.map { "\($0)" } ?? "DNF")
                .font(.headline.monospacedDigit())
                .foregroundStyle(place == nil ? Color.rvTextTertiary : Color.rvTextPrimary)
                .frame(width: 36, alignment: .leading)
            AvatarView(name: player?.name ?? "?", colorHex: player?.colorHex ?? "6E6E73", photo: player?.photo, size: 32)
            Text(name)
                .font(.body.weight(place == 1 ? .semibold : .regular))
                .foregroundStyle(place == 1 ? Color.rvAccent : Color.rvTextPrimary)
            Spacer()
            if let detail, participant.dnf == false {
                Text(detail)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color.rvTextSecondary)
            }
        }
        .padding(.vertical, Spacing.s)
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

    /// A team: overlapping avatars and all names, e.g. "You & Tom".
    private func team(_ side: Side, isWinner: Bool) -> some View {
        // You (or the friend) first, then the others.
        let anchor = side == .a ? sideA : sideB
        let members = [anchor].compactMap { $0 } + match.participants(on: side).filter { $0 !== anchor }
        let names = members.map { $0.player.map { $0.isMe ? "You" : $0.shortName } ?? "Deleted Player" }

        return VStack(spacing: Spacing.s) {
            HStack(spacing: -16) {
                ForEach(Array(members.prefix(4).enumerated()), id: \.offset) { _, member in
                    AvatarView(name: member.player?.name ?? "?", colorHex: member.player?.colorHex ?? "6E6E73",
                               photo: member.player?.photo, size: 48)
                        .overlay(Circle().strokeBorder(Color.rvSurface, lineWidth: 2))
                }
            }
            Text(names.joined(separator: " & "))
                .font(.headline)
                .foregroundStyle(isWinner ? Color.rvAccent : Color.rvTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(isWinner ? "Winner" : " ")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.rvAccent)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, 2)
                .background(isWinner ? Color.rvAccentSoft : .clear, in: Capsule())
        }
        .frame(maxWidth: 150)
    }

    // MARK: - Details per scoring type

    @ViewBuilder
    private var details: some View {
        if match.mode == .race {
            EmptyView()
        } else {
        switch match.scoringType {
        case .sets: setsDetails
        case .penalties: penaltyDetails
        case .fight: fightDetails
        case .time: timeDetails
        case .points, .placement, .winLoss: EmptyView()
        }
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

    // MARK: - Elo

    /// Elo change per player, e.g. "+14" / "−14" (plan.md §4 S3).
    @ViewBuilder
    private var eloChanges: some View {
        let changes = Elo.table(for: allMatches).changes(in: match)
        // Same order as the scoreboard: finishing order, or your side first.
        let ordered = match.mode == .race
            ? match.raceOrder
            : [sideA].compactMap { $0 } + match.participants(on: .a).filter { $0 !== sideA }
                + [sideB].compactMap { $0 } + match.participants(on: .b).filter { $0 !== sideB }
        let rows = ordered.compactMap { participant -> (name: String, change: Double)? in
            guard let player = participant.player, let change = changes[player.id] else { return nil }
            return (player.isMe ? "You" : player.shortName, change)
        }
        if !rows.isEmpty {
            section("Elo") {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        detailRow(row.name, Elo.changeText(row.change))
                    }
                }
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
        if let friend = sideB?.player {
            NavigationStack {
                MatchEntryView(sport: match.sport, me: me, friend: friend, isEdited: $isEdited,
                               initialDraft: MatchDraft(match: match, friend: friend),
                               onCancel: { isEditing = false }) { draft in
                    guard draft.isValid else { return }
                    if match.status == .confirmed {
                        // The old result keeps counting until the change is confirmed (plan.md §4 S3).
                        MatchSync.proposeChange(draft, to: match, context: context)
                    } else {
                        draft.apply(to: match, context: context)
                    }
                    Task { try? await online.syncMatches(me: me, context: context) }
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

#Preview("Go-Kart race") {
    let container = SampleData.container()
    let me = SampleData.player("Alex Morgan", in: container)
    let max = SampleData.player("Max Keller", in: container)
    var draft = MatchDraft(sport: .goKart)
    draft.racers = [RaceEntry(player: max, lapText: "1:01.870"), RaceEntry(player: me, lapText: "1:02.345"),
                    RaceEntry(player: SampleData.player("Tom Berger", in: container)),
                    RaceEntry(player: SampleData.player("Lukas Huber", in: container), dnf: true)]
    let race = draft.insertMatch(me: me, friend: max, into: container.mainContext)
    return NavigationStack {
        MatchDetailView(match: race, me: me, friend: max)
    }
    .modelContainer(container)
}
