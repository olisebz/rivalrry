import Foundation

/// A fight result as entered. `winnerSide == nil` means "Draw".
struct FightEntry: Equatable {
    var winnerSide: Side?
    var method: FightMethod
    var totalRounds: Int = ResultRules.defaultFightRounds
    /// Round the fight ended in. Required for KO, TKO and Retirement.
    var endRound: Int? = nil
    var roundScores: [RoundScore] = []
}

extension ResultRules {
    static let defaultFightRounds = 3
    static let fightRounds = 1...12
    /// Lowest score a fighter can get for a round in the 10-point system.
    static let lowestRoundScore = 6

    /// Checks a fight result (plan.md §2.2).
    static func validateFight(_ fight: FightEntry) -> Result<MatchResult, ResultIssue> {
        guard fightRounds.contains(fight.totalRounds) else { return .failure(.invalidRounds) }
        if fight.winnerSide == nil, fight.method != .points { return .failure(.drawOnlyByPoints) }

        // A decision on points always goes the full distance.
        let lastRound: Int
        if fight.method == .points {
            if let endRound = fight.endRound, endRound != fight.totalRounds { return .failure(.invalidEndRound) }
            lastRound = fight.totalRounds
        } else {
            guard let endRound = fight.endRound else { return .failure(.endRoundRequired) }
            guard (1...fight.totalRounds).contains(endRound) else { return .failure(.invalidEndRound) }
            lastRound = endRound
        }

        // Optional score card: one entry per fought round, 10 for the round winner.
        var seenRounds = Set<Int>()
        for score in fight.roundScores {
            let validRound = (1...lastRound).contains(score.round) && seenRounds.insert(score.round).inserted
            let validScore = max(score.scoreA, score.scoreB) == 10
                && min(score.scoreA, score.scoreB) >= lowestRoundScore
            guard validRound, validScore else { return .failure(.invalidRoundScore(round: score.round)) }
        }

        let outcome: Outcome = fight.winnerSide.map { .win($0) } ?? .draw
        return .success(MatchResult(outcome: outcome))
    }
}
