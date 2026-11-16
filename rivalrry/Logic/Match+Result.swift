import Foundation

extension Match {
    /// Scoring type, taking a custom sport into account.
    var scoringType: ScoringType { customSport?.scoringType ?? sportType.scoringType }

    /// Unconfirmed matches never count (plan.md §0).
    var countsTowardRecord: Bool { status == .local || status == .confirmed }

    func includes(_ player: Player) -> Bool {
        participants.contains { $0.player?.id == player.id }
    }

    func side(of player: Player) -> Side? {
        participants.first { $0.player?.id == player.id }?.side
    }

    func participants(on side: Side) -> [MatchParticipant] {
        participants.filter { $0.side == side }
    }

    /// The result computed from the stored data (plan.md §5). `nil` if the data is incomplete or invalid.
    var result: MatchResult? {
        switch scoringType {
        case .sets:
            guard let bestOf else { return nil }
            let entries = orderedSets.map {
                SetEntry(scoreA: $0.scoreA, scoreB: $0.scoreB, tiebreakA: $0.tiebreakA, tiebreakB: $0.tiebreakB)
            }
            return try? ResultRules.validateSets(entries, bestOf: bestOf, sport: sportType,
                                                 retiredSide: retiredSide).get()
        case .points:
            // A points match stores its score as a single SetScore (index 0).
            guard let score = orderedSets.first else { return nil }
            return try? ResultRules.validatePoints(scoreA: score.scoreA, scoreB: score.scoreB,
                                                   sport: sportType).get()
        case .penalties:
            if let shotsPerSide = penaltyShotsPerSide {
                let shots = orderedPenalties.map { PenaltyEntry(side: $0.side, scored: $0.scored) }
                return try? ResultRules.validatePenalties(shots, shotsPerSide: shotsPerSide).get()
            }
            // Without a shot count the goal count decides.
            let goalsA = penalties.filter { $0.side == .a && $0.scored }.count
            let goalsB = penalties.filter { $0.side == .b && $0.scored }.count
            guard goalsA != goalsB else { return nil }
            return MatchResult(outcome: .win(goalsA > goalsB ? .a : .b), scoreA: goalsA, scoreB: goalsB)
        case .fight:
            guard let fight else { return nil }
            let entry = FightEntry(winnerSide: fight.winnerSide, method: fight.method,
                                   totalRounds: fight.totalRounds, endRound: fight.endRound,
                                   roundScores: fight.roundScores)
            return try? ResultRules.validateFight(entry).get()
        case .time:
            return timeResult
        case .placement, .winLoss:
            // Races and custom sports come in Phase 2.
            return nil
        }
    }

    /// Running 1v1 (plan.md §2.2).
    private var timeResult: MatchResult? {
        guard mode == .oneVsOne,
              let a = participants(on: .a).first,
              let b = participants(on: .b).first else { return nil }
        return try? ResultRules.validateTime(timeA: a.timeMs, dnfA: a.dnf, timeB: b.timeMs, dnfB: b.dnf,
                                             distanceMeters: distanceMeters).get()
    }
}
