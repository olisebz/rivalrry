import Foundation

/// One penalty as entered. The array order is the shooting order.
struct PenaltyEntry: Equatable {
    var side: Side
    var scored: Bool
}

extension ResultRules {
    /// Selectable shots per side (plan.md §2.2).
    static let penaltyShotOptions = [3, 5, 10]
    static let defaultPenaltyShots = 5

    /// Shots after the regular ones are "Sudden Death". `index` is 0-based over all shots.
    static func isSuddenDeath(index: Int, shotsPerSide: Int) -> Bool {
        index >= shotsPerSide * 2
    }

    /// Checks a penalty shootout (plan.md §2.2).
    /// Sides alternate A, B, A, B … The shootout ends early once one side can't catch up.
    /// If it's level after all regular shots, sudden death pairs follow until one pair is decided.
    static func validatePenalties(_ shots: [PenaltyEntry], shotsPerSide: Int) -> Result<MatchResult, ResultIssue> {
        guard penaltyShotOptions.contains(shotsPerSide) else { return .failure(.invalidShotCount) }

        var goalsA = 0, goalsB = 0
        var takenA = 0, takenB = 0
        var winner: Side?

        for (index, shot) in shots.enumerated() {
            guard winner == nil else { return .failure(.shotsAfterDecision) }
            let expectedSide: Side = index.isMultiple(of: 2) ? .a : .b
            guard shot.side == expectedSide else { return .failure(.invalidShotOrder) }

            if shot.side == .a {
                takenA += 1
                if shot.scored { goalsA += 1 }
            } else {
                takenB += 1
                if shot.scored { goalsB += 1 }
            }

            if isSuddenDeath(index: index, shotsPerSide: shotsPerSide) {
                // Decided only after a complete pair.
                if shot.side == .b, goalsA != goalsB {
                    winner = goalsA > goalsB ? .a : .b
                }
            } else {
                let remainingA = shotsPerSide - takenA
                let remainingB = shotsPerSide - takenB
                if goalsA > goalsB + remainingB { winner = .a }
                if goalsB > goalsA + remainingA { winner = .b }
            }
        }

        guard let winner else { return .failure(.shootoutNotDecided) }
        return .success(MatchResult(outcome: .win(winner), scoreA: goalsA, scoreB: goalsB))
    }
}
