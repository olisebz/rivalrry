import Foundation

extension ResultRules {
    /// Custom "Win / Loss": just who won, or a draw if the sport allows it (plan.md §2.2).
    static func validateWinLoss(winner: Side?, sport: Sport) -> Result<MatchResult, ResultIssue> {
        guard let winner else {
            return sport.allowsDraw ? .success(MatchResult(outcome: .draw)) : .failure(.drawNotAllowed(sport))
        }
        return .success(MatchResult(outcome: .win(winner)))
    }
}
