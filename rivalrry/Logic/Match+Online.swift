import Foundation

extension Match {
    // MARK: - Stored online state

    /// A change to this confirmed match that waits for the opponents (plan.md §4 S3).
    var pendingChange: PendingChange? {
        get { pendingChangeData.flatMap { try? JSONDecoder().decode(PendingChange.self, from: $0) } }
        set { pendingChangeData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    /// An open "Request deletion".
    var deletionRequest: DeletionRequest? {
        get { deletionRequestData.flatMap { try? JSONDecoder().decode(DeletionRequest.self, from: $0) } }
        set { deletionRequestData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    // MARK: - Who confirms

    /// Who has to confirm: the other team (1v1, Team) or everyone else (Race). Same rule as
    /// `MatchRecord.opponentUserIDs`.
    var confirmingParticipants: [MatchParticipant] {
        let creatorSide = participants.first { $0.player?.id == createdBy?.id }?.side
        return participants.filter {
            $0.player?.id != createdBy?.id && (mode == .race || $0.side != creatorSide)
        }
    }

    /// Opponents who haven't confirmed the current version yet.
    var waitingParticipants: [MatchParticipant] {
        confirmingParticipants.filter { !confirmedUserIDs.contains($0.player?.cloudUserID ?? "") }
    }

    /// Opponents who haven't confirmed the proposed change yet.
    var waitingForChange: [MatchParticipant] {
        guard let change = pendingChange else { return [] }
        return confirmingParticipants.filter {
            !change.confirmation.confirmedUserIDs.contains($0.player?.cloudUserID ?? "")
        }
    }

    // MARK: - Texts

    /// S3 status banner (plan.md §4 S3): "Waiting for Max to confirm", "Confirmed",
    /// "Rejected by Max: It was 21–19". `nil` for local matches.
    var statusText: String? {
        switch status {
        case .local:
            return nil
        case .confirmed:
            return "Confirmed"
        case .pending:
            return waitingText(waitingParticipants, for: "confirm")
        case .rejected:
            return rejectedText(by: rejectedByUserID, reason: rejectionReason, prefix: "Rejected")
        }
    }

    /// Second banner line for a change to a confirmed match.
    var changeText: String? {
        guard let change = pendingChange else { return nil }
        switch change.confirmation.status {
        case .rejected:
            return rejectedText(by: change.confirmation.rejectedByUserID,
                                reason: change.confirmation.rejectionReason, prefix: "Change rejected")
        default:
            return "Change " + waitingText(waitingForChange, for: "confirm").lowercasedFirst
        }
    }

    /// "Max wants to delete this match", "Waiting for Tom to approve deletion".
    func deletionText(me: Player) -> String? {
        guard let request = deletionRequest else { return nil }
        let waiting = request.approverUserIDs.filter { !request.approvedUserIDs.contains($0) }
        if request.requestedBy == me.cloudUserID {
            return "Waiting for \(names(ofUserIDs: waiting)) to approve deletion"
        }
        return "\(names(ofUserIDs: [request.requestedBy]).capitalizedFirst) wants to delete this match"
    }

    /// "Waiting for Max and Tom to confirm"; "you" for yourself.
    private func waitingText(_ waiting: [MatchParticipant], for action: String) -> String {
        let names = waiting.map(Self.name(of:))
        guard !names.isEmpty else { return "Waiting for confirmation" }
        return "Waiting for \(Self.list(names)) to \(action)"
    }

    private func rejectedText(by userID: String?, reason: String?, prefix: String) -> String {
        let name = userID.map { names(ofUserIDs: [$0]) } ?? "an opponent"
        guard let reason, !reason.isEmpty else { return "\(prefix) by \(name)" }
        return "\(prefix) by \(name): \(reason)"
    }

    private func names(ofUserIDs userIDs: [String]) -> String {
        Self.list(userIDs.map { id in
            participants.first { $0.player?.cloudUserID == id }.map(Self.name(of:)) ?? "an opponent"
        })
    }

    private static func name(of participant: MatchParticipant) -> String {
        participant.player.map { $0.isMe ? "you" : $0.shortName } ?? "Deleted Player"
    }

    private static func list(_ names: [String]) -> String {
        names.formatted(.list(type: .and).locale(Locale(identifier: "en_US")))
    }

    /// Result of the proposed change from `player`'s point of view, e.g. "2 – 0".
    func changeScoreText(for player: Player) -> String? {
        guard let change = pendingChange, let userID = player.cloudUserID else { return nil }
        return change.record.scoreText(forUserID: userID, sport: sport)
    }

    // MARK: - Rights (plan.md §4 S3, Phase 3)

    private func isCreator(_ me: Player) -> Bool { createdBy?.id == me.id }

    /// "Edit": local matches any time; online only the creator. A confirmed match becomes a change request.
    func canEdit(by me: Player) -> Bool {
        switch status {
        case .local: true
        case .pending, .rejected: isCreator(me)
        case .confirmed: isCreator(me) && deletionRequest == nil
        }
    }

    /// "Delete" right away: local matches, or your own online match while `Pending` or `Rejected`.
    func canDelete(by me: Player) -> Bool {
        switch status {
        case .local: true
        case .pending, .rejected: isCreator(me)
        case .confirmed: false
        }
    }

    /// "Request deletion" for a confirmed match: the creator or anyone who confirms, once at a time.
    func canRequestDeletion(by me: Player) -> Bool {
        guard status == .confirmed, deletionRequest == nil, let userID = me.cloudUserID else { return false }
        return isCreator(me) || confirmingParticipants.contains { $0.player?.cloudUserID == userID }
    }

    /// "Remind" once every 24 h while your match or your change is `Pending` (plan.md §4 S3).
    var isWaitingForOthers: Bool {
        status == .pending || pendingChange?.confirmation.status == .pending
    }

    func canRemind(by me: Player, now: Date = Date()) -> Bool {
        guard isCreator(me), isWaitingForOthers else { return false }
        guard let remindedAt else { return true }
        return now.timeIntervalSince(remindedAt) >= Self.remindInterval
    }

    static let remindInterval: TimeInterval = 24 * 60 * 60

    // MARK: - S6

    /// "To confirm": someone else's match (or change) that waits for your answer.
    func needsConfirmation(by me: Player) -> Bool {
        guard let userID = me.cloudUserID, !isCreator(me),
              confirmingParticipants.contains(where: { $0.player?.cloudUserID == userID }) else { return false }
        if status == .pending { return !confirmedUserIDs.contains(userID) }
        if let change = pendingChange, change.confirmation.status == .pending {
            return !change.confirmation.confirmedUserIDs.contains(userID)
        }
        return false
    }

    /// "Deletion requests": someone asked to delete and your approval is missing.
    func needsDeletionAnswer(by me: Player) -> Bool {
        guard let request = deletionRequest, let userID = me.cloudUserID else { return false }
        return request.approverUserIDs.contains(userID) && !request.approvedUserIDs.contains(userID)
    }
}

/// The S6 sections built from matches (plan.md §4 S6).
struct MatchRequests {
    /// One bulk request per friend who imported old matches (plan.md §6.3 point 4).
    struct ImportGroup: Identifiable {
        let creator: Player
        let matches: [Match]
        var id: UUID { creator.id }

        /// "Alex imported 12 matches with you"
        var title: String {
            "\(creator.shortName) imported \(matches.count) \(matches.count == 1 ? "match" : "matches") with you"
        }
    }

    var toConfirm: [Match] = []
    var imported: [ImportGroup] = []
    var deletionRequests: [Match] = []
    var waitingForOthers: [Match] = []

    init(matches: [Match], me: Player) {
        let sorted = matches.sorted { $0.date > $1.date }
        let open = sorted.filter { $0.needsConfirmation(by: me) }
        // Imported old matches come as one request per friend, not one by one.
        let importedOpen = open.filter { $0.isImported && $0.status == .pending }
        toConfirm = open.filter { !($0.isImported && $0.status == .pending) }
        let byCreator = importedOpen.compactMap { match in match.createdBy.map { (creator: $0, match: match) } }
        imported = Dictionary(grouping: byCreator) { $0.creator.id }
            .values
            .compactMap { group in group.first.map { ImportGroup(creator: $0.creator, matches: group.map(\.match)) } }
            .sorted { $0.creator.name.localizedStandardCompare($1.creator.name) == .orderedAscending }
        deletionRequests = sorted.filter { $0.needsDeletionAnswer(by: me) }
        waitingForOthers = sorted.filter { $0.createdBy?.id == me.id && $0.isWaitingForOthers }
    }

    /// Things you need to handle, for the badge (plan.md §4 S6). An import counts once;
    /// "Waiting for others" doesn't count.
    var actionCount: Int { toConfirm.count + imported.count + deletionRequests.count }
}

extension MatchRecord {
    /// The result of this version, like `Match.result`.
    func result(sport: Sport) -> MatchResult? {
        let ordered = sets.sorted { $0.index < $1.index }
        switch sport.scoringType {
        case .sets:
            guard let bestOf else { return nil }
            let entries = ordered.map {
                SetEntry(scoreA: $0.scoreA, scoreB: $0.scoreB, tiebreakA: $0.tiebreakA, tiebreakB: $0.tiebreakB)
            }
            return try? ResultRules.validateSets(entries, bestOf: bestOf, sport: sport, retiredSide: retiredSide).get()
        case .points:
            guard let score = ordered.first else { return nil }
            return try? ResultRules.validatePoints(scoreA: score.scoreA, scoreB: score.scoreB, sport: sport).get()
        case .penalties:
            guard let shotsPerSide = penaltyShotsPerSide else { return nil }
            let shots = penalties.sorted { $0.index < $1.index }.map { PenaltyEntry(side: $0.side, scored: $0.scored) }
            return try? ResultRules.validatePenalties(shots, shotsPerSide: shotsPerSide).get()
        case .fight:
            guard let fight else { return nil }
            return try? ResultRules.validateFight(FightEntry(
                winnerSide: fight.winnerSide, method: fight.method, totalRounds: fight.totalRounds,
                endRound: fight.endRound, roundScores: fight.roundScores)).get()
        case .time:
            guard mode == .oneVsOne,
                  let a = participants.first(where: { $0.side == .a }),
                  let b = participants.first(where: { $0.side == .b }) else { return nil }
            return try? ResultRules.validateTime(timeA: a.timeMs, dnfA: a.dnf, timeB: b.timeMs, dnfB: b.dnf,
                                                 distanceMeters: distanceMeters,
                                                 needsDistance: sport.usesDistance).get()
        case .winLoss:
            guard let score = ordered.first else { return nil }
            let winner: Side? = score.scoreA > score.scoreB ? .a : score.scoreB > score.scoreA ? .b : nil
            return try? ResultRules.validateWinLoss(winner: winner, sport: sport).get()
        case .placement:
            return nil
        }
    }

    /// Like `Match.scoreText(for:)`, own score first. Only for 1v1 and team matches (races can't be edited).
    func scoreText(forUserID userID: String, sport: Sport) -> String {
        guard let mySide = participants.first(where: { $0.userID == userID })?.side,
              let result = result(sport: sport) else { return "–" }
        switch sport.scoringType {
        case .sets, .points, .penalties:
            guard let a = result.scoreA, let b = result.scoreB else { return "–" }
            return mySide == .b ? "\(b) – \(a)" : "\(a) – \(b)"
        case .fight:
            if case .draw = result.outcome { return "Draw" }
            return fight?.method.displayName ?? "–"
        case .time:
            let time = { (side: Side) -> String in
                guard let participant = participants.first(where: { $0.side == side }) else { return "–" }
                if participant.dnf { return "DNF" }
                return participant.timeMs.map(TimeText.text(milliseconds:)) ?? "–"
            }
            return "\(time(mySide)) – \(time(mySide.opponent))"
        case .winLoss:
            switch result.outcome {
            case .draw: return "Draw"
            case .win(let side): return side == mySide ? "Win" : "Loss"
            }
        case .placement:
            return "–"
        }
    }
}

private extension String {
    var lowercasedFirst: String { prefix(1).lowercased() + dropFirst() }
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// "Reminded 3 hours ago" after "Remind".
enum RemindText {
    static func text(for date: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .full
        return "Reminded " + formatter.localizedString(for: min(date, now), relativeTo: now)
    }
}
