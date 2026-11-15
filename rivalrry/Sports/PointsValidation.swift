import Foundation

extension ResultRules {

    /// Checks a points result, e.g. Football or Basketball (plan.md §2.2).
    static func validatePoints(scoreA: Int, scoreB: Int, sport: SportType) -> Result<MatchResult, ResultIssue> {
        guard scoreA >= 0, scoreB >= 0 else { return .failure(.negativeScore) }
        if scoreA == scoreB {
            guard sport.allowsDraw else { return .failure(.drawNotAllowed(sport)) }
            return .success(MatchResult(outcome: .draw, scoreA: scoreA, scoreB: scoreB))
        }
        let winner: Side = scoreA > scoreB ? .a : .b
        return .success(MatchResult(outcome: .win(winner), scoreA: scoreA, scoreB: scoreB))
    }
}
