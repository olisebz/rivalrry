import Foundation

enum DuelOutcome: Equatable {
    case win, loss, draw
}

/// A direct comparison between two players, seen from one of them (plan.md §1).
struct Duel {
    let match: Match
    /// `nil` if the opponent was deleted ("Deleted Player").
    let opponent: Player?
    let outcome: DuelOutcome

    var date: Date { match.date }
}

extension Match {
    /// All duels of `player` in this match (plan.md §2.3).
    /// 1v1 and Team: one duel against every player on the other side. Partners are no duel.
    /// Races follow in Phase 2.
    func duels(for player: Player) -> [Duel] {
        guard countsTowardRecord, mode != .race,
              let mySide = side(of: player),
              let result else { return [] }

        let outcome: DuelOutcome
        switch result.outcome {
        case .draw: outcome = .draw
        case .win(let side): outcome = side == mySide ? .win : .loss
        }
        return participants(on: mySide.opponent).map {
            Duel(match: self, opponent: $0.player, outcome: outcome)
        }
    }
}
