import Testing
@testable import rivalrry

/// Fight rules from plan.md §2.2.
struct FightValidationTests {

    @Test func winsByMethod() {
        #expect(ResultRules.validateFight(FightEntry(winnerSide: .a, method: .ko, endRound: 2))
                == .success(MatchResult(outcome: .win(.a))))
        #expect(ResultRules.validateFight(FightEntry(winnerSide: .b, method: .tko, endRound: 3))
                == .success(MatchResult(outcome: .win(.b))))
        #expect(ResultRules.validateFight(FightEntry(winnerSide: .a, method: .retirement, endRound: 1))
                == .success(MatchResult(outcome: .win(.a))))
        #expect(ResultRules.validateFight(FightEntry(winnerSide: .b, method: .points))
                == .success(MatchResult(outcome: .win(.b))))
    }

    @Test func drawOnlyOnPoints() {
        #expect(ResultRules.validateFight(FightEntry(winnerSide: nil, method: .points))
                == .success(MatchResult(outcome: .draw)))
        #expect(ResultRules.validateFight(FightEntry(winnerSide: nil, method: .ko, endRound: 2))
                == .failure(.drawOnlyByPoints))
    }

    @Test func endRound() {
        #expect(ResultRules.validateFight(FightEntry(winnerSide: .a, method: .ko)) == .failure(.endRoundRequired))
        #expect(ResultRules.validateFight(FightEntry(winnerSide: .a, method: .ko, endRound: 4))
                == .failure(.invalidEndRound))
        #expect(ResultRules.validateFight(FightEntry(winnerSide: .a, method: .ko, endRound: 0))
                == .failure(.invalidEndRound))
        // Points always go the full distance.
        #expect(ResultRules.validateFight(FightEntry(winnerSide: .a, method: .points, endRound: 2))
                == .failure(.invalidEndRound))
        #expect(ResultRules.validateFight(FightEntry(winnerSide: .a, method: .points, endRound: 3))
                == .success(MatchResult(outcome: .win(.a))))
    }

    @Test func totalRounds() {
        #expect(ResultRules.validateFight(FightEntry(winnerSide: .a, method: .points, totalRounds: 0))
                == .failure(.invalidRounds))
        #expect(ResultRules.validateFight(FightEntry(winnerSide: .a, method: .points, totalRounds: 13))
                == .failure(.invalidRounds))
        #expect(ResultRules.validateFight(FightEntry(winnerSide: .a, method: .ko, totalRounds: 12, endRound: 12))
                == .success(MatchResult(outcome: .win(.a))))
    }

    @Test func scoreCard() {
        let card = [RoundScore(round: 1, scoreA: 10, scoreB: 9),
                    RoundScore(round: 2, scoreA: 9, scoreB: 10),
                    RoundScore(round: 3, scoreA: 10, scoreB: 10)]
        #expect(ResultRules.validateFight(FightEntry(winnerSide: nil, method: .points, roundScores: card))
                == .success(MatchResult(outcome: .draw)))

        let notTen = [RoundScore(round: 1, scoreA: 9, scoreB: 8)]
        #expect(ResultRules.validateFight(FightEntry(winnerSide: .a, method: .points, roundScores: notTen))
                == .failure(.invalidRoundScore(round: 1)))

        let tooLow = [RoundScore(round: 1, scoreA: 10, scoreB: 5)]
        #expect(ResultRules.validateFight(FightEntry(winnerSide: .a, method: .points, roundScores: tooLow))
                == .failure(.invalidRoundScore(round: 1)))

        let duplicate = [RoundScore(round: 1, scoreA: 10, scoreB: 9), RoundScore(round: 1, scoreA: 10, scoreB: 9)]
        #expect(ResultRules.validateFight(FightEntry(winnerSide: .a, method: .points, roundScores: duplicate))
                == .failure(.invalidRoundScore(round: 1)))

        // No scores for rounds after a KO.
        let afterKO = [RoundScore(round: 3, scoreA: 10, scoreB: 9)]
        #expect(ResultRules.validateFight(FightEntry(winnerSide: .a, method: .ko, endRound: 2, roundScores: afterKO))
                == .failure(.invalidRoundScore(round: 3)))
    }
}
