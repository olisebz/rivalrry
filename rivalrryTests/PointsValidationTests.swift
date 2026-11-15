import Testing
@testable import rivalrry

/// Points rules from plan.md §2.2.
struct PointsValidationTests {

    @Test func footballWinAndDraw() {
        #expect(ResultRules.validatePoints(scoreA: 3, scoreB: 2, sport: .football)
                == .success(MatchResult(outcome: .win(.a), scoreA: 3, scoreB: 2)))
        #expect(ResultRules.validatePoints(scoreA: 4, scoreB: 5, sport: .football)
                == .success(MatchResult(outcome: .win(.b), scoreA: 4, scoreB: 5)))
        #expect(ResultRules.validatePoints(scoreA: 0, scoreB: 0, sport: .football)
                == .success(MatchResult(outcome: .draw, scoreA: 0, scoreB: 0)))
    }

    @Test func basketballCantEndInATie() {
        #expect(ResultRules.validatePoints(scoreA: 21, scoreB: 21, sport: .basketball)
                == .failure(.drawNotAllowed(.basketball)))
        #expect(ResultRules.validatePoints(scoreA: 21, scoreB: 21, sport: .basketball).issue?.message
                == "Basketball can't end in a tie")
        #expect(ResultRules.validatePoints(scoreA: 21, scoreB: 18, sport: .basketball)
                == .success(MatchResult(outcome: .win(.a), scoreA: 21, scoreB: 18)))
    }

    @Test func negativeScores() {
        #expect(ResultRules.validatePoints(scoreA: -1, scoreB: 2, sport: .football) == .failure(.negativeScore))
    }
}

extension Result where Failure == ResultIssue {
    var issue: ResultIssue? {
        if case .failure(let issue) = self { return issue }
        return nil
    }
}
