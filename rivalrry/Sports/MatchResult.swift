import Foundation

enum Outcome: Equatable {
    case win(Side)
    case draw
}

/// The computed result of a match. Never stored (plan.md §5).
struct MatchResult: Equatable {
    let outcome: Outcome
    /// Sets won, points or goals. `nil` for fights.
    let scoreA: Int?
    let scoreB: Int?

    init(outcome: Outcome, scoreA: Int? = nil, scoreB: Int? = nil) {
        self.outcome = outcome
        self.scoreA = scoreA
        self.scoreB = scoreB
    }
}

/// Validation rules per scoring type (plan.md §2.2).
/// Inputs are plain values so drafts can be checked before anything is saved.
enum ResultRules {}

/// Why a result can't be saved. `message` is shown below the disabled "Save Match" button.
enum ResultIssue: Error, Equatable {
    // sets
    case invalidFormat
    case noSets
    /// Set not won by the rules (unfinished or impossible score). `set` is 1-based.
    case setScore(set: Int, sport: SportType)
    case tiebreakMissing(set: Int)
    case invalidTiebreak(set: Int, sport: SportType)
    case tiebreakNotAllowed(set: Int, sport: SportType)
    case tooManySets
    case matchNotDecided(setsNeeded: Int)
    case retiredAfterMatchEnded
    // points
    case negativeScore
    case drawNotAllowed(SportType)
    // penalties
    case invalidShotCount
    case invalidShotOrder
    case shotsAfterDecision
    case shootoutNotDecided
    // fight
    case invalidRounds
    case drawOnlyByPoints
    case endRoundRequired
    case invalidEndRound
    case invalidRoundScore(round: Int)
    // team
    case teamsUnequal
    case teamSize(ClosedRange<Int>)
    // time
    case invalidDistance
    case missingTime

    var message: String {
        switch self {
        case .invalidFormat:
            "Choose a format."
        case .noSets:
            "Add at least one set."
        case .setScore(let set, let sport):
            "Set \(set): \(Self.setRuleText(for: sport))."
        case .tiebreakMissing(let set):
            "Set \(set): enter the tiebreak score."
        case .invalidTiebreak(let set, let sport):
            "Set \(set): the tiebreak winner needs \(sport.setRules?.tiebreak?.pointsToWin ?? 7) points and a 2-point lead."
        case .tiebreakNotAllowed(let set, let sport):
            "Set \(set): a tiebreak is only played at \(Self.tiebreakScore(for: sport))."
        case .tooManySets:
            "The match was already decided. Remove the extra set."
        case .matchNotDecided(let setsNeeded):
            "The winner needs \(setsNeeded) \(setsNeeded == 1 ? "set" : "sets")."
        case .retiredAfterMatchEnded:
            "The match was already decided."
        case .negativeScore:
            "Scores can't be negative."
        case .drawNotAllowed(let sport):
            "\(sport.displayName) can't end in a tie"
        case .invalidShotCount:
            "Choose 3, 5 or 10 shots."
        case .invalidShotOrder:
            "Shots must alternate between both sides."
        case .shotsAfterDecision:
            "The shootout was already decided. Remove the extra shots."
        case .shootoutNotDecided:
            "The shootout isn't decided yet."
        case .invalidRounds:
            "Choose between 1 and \(ResultRules.fightRounds.upperBound) rounds."
        case .drawOnlyByPoints:
            "A draw is only possible on points."
        case .endRoundRequired:
            "Choose the round the fight ended in."
        case .invalidEndRound:
            "The fight can't end after the last round."
        case .invalidRoundScore(let round):
            "Round \(round): use the 10-point system, e.g. 10–9."
        case .teamsUnequal:
            "Both teams need the same number of players."
        case .teamSize(let sizes):
            sizes.lowerBound == sizes.upperBound
                ? "Each team needs \(sizes.lowerBound) players."
                : "Each team needs \(sizes.lowerBound)–\(sizes.upperBound) players."
        case .invalidDistance:
            "Enter a distance."
        case .missingTime:
            "Enter a time or DNF for both players."
        }
    }

    private static func setRuleText(for sport: SportType) -> String {
        guard let rules = sport.setRules else { return "invalid score" }
        if rules.tiebreak != nil {
            return "the winner needs \(rules.pointsToWin) games and a \(rules.winBy)-game lead, "
                + "or \(tiebreakScore(for: sport)) with a tiebreak"
        }
        return "the winner needs \(rules.pointsToWin) points and a \(rules.winBy)-point lead"
    }

    private static func tiebreakScore(for sport: SportType) -> String {
        let games = sport.setRules?.pointsToWin ?? 6
        return "\(games + 1)–\(games)"
    }
}
