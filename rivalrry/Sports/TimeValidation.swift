import Foundation

extension ResultRules {
    /// Selectable distances in meters (plan.md §2.2). Any other positive value is a custom distance.
    static let runningDistances = [60, 100, 200, 400, 1_000, 5_000, 10_000]

    /// Checks a running result between two sides (plan.md §2.2).
    /// Faster time wins, exactly the same time is a draw, DNF loses, both DNF is a draw.
    static func validateTime(timeA: Int?, dnfA: Bool, timeB: Int?, dnfB: Bool,
                             distanceMeters: Int?) -> Result<MatchResult, ResultIssue> {
        guard let distanceMeters, distanceMeters > 0 else { return .failure(.invalidDistance) }
        if !dnfA, (timeA ?? 0) <= 0 { return .failure(.missingTime) }
        if !dnfB, (timeB ?? 0) <= 0 { return .failure(.missingTime) }

        switch (dnfA, dnfB) {
        case (true, true): return .success(MatchResult(outcome: .draw))
        case (true, false): return .success(MatchResult(outcome: .win(.b)))
        case (false, true): return .success(MatchResult(outcome: .win(.a)))
        case (false, false):
            let a = timeA ?? 0, b = timeB ?? 0
            if a == b { return .success(MatchResult(outcome: .draw)) }
            return .success(MatchResult(outcome: .win(a < b ? .a : .b)))
        }
    }
}
