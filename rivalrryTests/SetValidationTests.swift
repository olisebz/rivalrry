import Testing
@testable import rivalrry

/// Set rules from plan.md §2.2.
struct SetValidationTests {

    private func check(_ sport: SportType, _ a: Int, _ b: Int, tiebreak: (Int, Int)? = nil) -> SetCheck {
        let set = SetEntry(scoreA: a, scoreB: b, tiebreakA: tiebreak?.0, tiebreakB: tiebreak?.1)
        return ResultRules.check(set, rules: sport.setRules!)
    }

    // MARK: - Single sets

    @Test func badmintonSets() {
        #expect(check(.badminton, 21, 19) == .won(.a))
        #expect(check(.badminton, 15, 21) == .won(.b))
        #expect(check(.badminton, 21, 0) == .won(.a))
        #expect(check(.badminton, 22, 20) == .won(.a))
        #expect(check(.badminton, 28, 26) == .won(.a))
        #expect(check(.badminton, 30, 28) == .won(.a))
        #expect(check(.badminton, 30, 29) == .won(.a))   // next point wins at 29:29
        #expect(check(.badminton, 29, 30) == .won(.b))

        #expect(check(.badminton, 21, 20) == .unfinished)
        #expect(check(.badminton, 21, 21) == .unfinished)
        #expect(check(.badminton, 29, 29) == .unfinished)
        #expect(check(.badminton, 18, 12) == .unfinished)

        #expect(check(.badminton, 23, 20) == .invalidScore)
        #expect(check(.badminton, 31, 29) == .invalidScore)
        #expect(check(.badminton, 30, 30) == .invalidScore)
        #expect(check(.badminton, -1, 21) == .invalidScore)
    }

    @Test func pingPongSets() {
        #expect(check(.pingPong, 11, 9) == .won(.a))
        #expect(check(.pingPong, 14, 12) == .won(.a))
        #expect(check(.pingPong, 30, 32) == .won(.b))    // no cap
        #expect(check(.pingPong, 11, 10) == .unfinished)
        #expect(check(.pingPong, 12, 9) == .invalidScore)
    }

    @Test func tennisSets() {
        #expect(check(.tennis, 6, 4) == .won(.a))
        #expect(check(.tennis, 6, 0) == .won(.a))
        #expect(check(.tennis, 7, 5) == .won(.a))
        #expect(check(.tennis, 5, 7) == .won(.b))
        #expect(check(.tennis, 6, 5) == .unfinished)
        #expect(check(.tennis, 6, 6) == .unfinished)
        #expect(check(.tennis, 7, 4) == .invalidScore)
        #expect(check(.tennis, 8, 6) == .invalidScore)
        #expect(check(.tennis, 7, 7) == .invalidScore)
    }

    @Test func tennisTiebreaks() {
        #expect(check(.tennis, 7, 6, tiebreak: (7, 5)) == .won(.a))
        #expect(check(.tennis, 7, 6, tiebreak: (10, 8)) == .won(.a))
        #expect(check(.tennis, 6, 7, tiebreak: (3, 7)) == .won(.b))
        #expect(check(.tennis, 7, 6) == .needsTiebreak)
        #expect(check(.tennis, 7, 6, tiebreak: (6, 5)) == .needsTiebreak)
        #expect(check(.tennis, 7, 6, tiebreak: (5, 7)) == .invalidTiebreak)  // wrong winner
        #expect(check(.tennis, 7, 6, tiebreak: (9, 5)) == .invalidTiebreak)
        #expect(check(.tennis, 6, 4, tiebreak: (7, 5)) == .tiebreakNotAllowed)
        #expect(check(.badminton, 21, 19, tiebreak: (7, 5)) == .tiebreakNotAllowed)
    }

    @Test func padelUsesTennisRules() {
        #expect(check(.padel, 7, 6, tiebreak: (7, 4)) == .won(.a))
        #expect(check(.padel, 7, 6) == .needsTiebreak)
    }

    // MARK: - Matches

    private func sets(_ scores: (Int, Int)...) -> [SetEntry] {
        scores.map { SetEntry(scoreA: $0.0, scoreB: $0.1) }
    }

    @Test func badmintonMatchFromMockup() {
        let result = ResultRules.validateSets(sets((21, 19), (18, 21), (21, 17)), bestOf: 3, sport: .badminton)
        #expect(result == .success(MatchResult(outcome: .win(.a), scoreA: 2, scoreB: 1)))
    }

    @Test func invalidSetFromMockup() {
        let result = ResultRules.validateSets(sets((21, 19), (21, 21)), bestOf: 3, sport: .badminton)
        #expect(result == .failure(.setScore(set: 2, sport: .badminton)))
        #expect(ResultIssue.setScore(set: 2, sport: .badminton).message
                == "Set 2: the winner needs 21 points and a 2-point lead.")
    }

    @Test func bestOfOne() {
        let result = ResultRules.validateSets(sets((9, 11)), bestOf: 1, sport: .pingPong)
        #expect(result == .success(MatchResult(outcome: .win(.b), scoreA: 0, scoreB: 1)))
    }

    @Test func pingPongBestOfFive() {
        let result = ResultRules.validateSets(sets((11, 5), (9, 11), (11, 8), (11, 13), (12, 10)),
                                              bestOf: 5, sport: .pingPong)
        #expect(result == .success(MatchResult(outcome: .win(.a), scoreA: 3, scoreB: 2)))
    }

    @Test func formatMustBeAllowedForSport() {
        #expect(ResultRules.validateSets(sets((21, 10)), bestOf: 5, sport: .badminton) == .failure(.invalidFormat))
        #expect(ResultRules.validateSets(sets((6, 4)), bestOf: 5, sport: .padel) == .failure(.invalidFormat))
        #expect(ResultRules.validateSets(sets((3, 1)), bestOf: 1, sport: .football) == .failure(.invalidFormat))
    }

    @Test func noSetsAfterMatchIsDecided() {
        let result = ResultRules.validateSets(sets((21, 10), (21, 10), (10, 21)), bestOf: 3, sport: .badminton)
        #expect(result == .failure(.tooManySets))
    }

    @Test func matchMustBeDecided() {
        #expect(ResultRules.validateSets([], bestOf: 3, sport: .badminton) == .failure(.noSets))
        let result = ResultRules.validateSets(sets((21, 10), (10, 21)), bestOf: 3, sport: .badminton)
        #expect(result == .failure(.matchNotDecided(setsNeeded: 2)))
    }

    @Test func tiebreakMissingInMatch() {
        let result = ResultRules.validateSets(sets((6, 4), (7, 6)), bestOf: 3, sport: .tennis)
        #expect(result == .failure(.tiebreakMissing(set: 2)))

        let withTiebreak = [SetEntry(scoreA: 6, scoreB: 4), SetEntry(scoreA: 7, scoreB: 6, tiebreakA: 7, tiebreakB: 3)]
        #expect(ResultRules.validateSets(withTiebreak, bestOf: 3, sport: .tennis)
                == .success(MatchResult(outcome: .win(.a), scoreA: 2, scoreB: 0)))
    }

    // MARK: - "Match not finished"

    @Test func retirementWinsForOpponent() {
        // B gives up during set 2.
        let result = ResultRules.validateSets(sets((21, 19), (8, 4)), bestOf: 3, sport: .badminton, retiredSide: .b)
        #expect(result == .success(MatchResult(outcome: .win(.a), scoreA: 1, scoreB: 0)))

        // A leads in sets but gives up: B wins.
        let leading = ResultRules.validateSets(sets((21, 19)), bestOf: 3, sport: .badminton, retiredSide: .a)
        #expect(leading == .success(MatchResult(outcome: .win(.b), scoreA: 1, scoreB: 0)))
    }

    @Test func retirementBeforeFirstPoint() {
        let result = ResultRules.validateSets([], bestOf: 3, sport: .tennis, retiredSide: .a)
        #expect(result == .success(MatchResult(outcome: .win(.b), scoreA: 0, scoreB: 0)))
    }

    @Test func retirementDuringTiebreak() {
        let result = ResultRules.validateSets(sets((7, 6)), bestOf: 3, sport: .tennis, retiredSide: .b)
        #expect(result == .success(MatchResult(outcome: .win(.a), scoreA: 0, scoreB: 0)))
    }

    @Test func retirementRules() {
        // Only the last set may be unfinished.
        let earlierOpen = ResultRules.validateSets(sets((15, 10), (21, 10)), bestOf: 3, sport: .badminton, retiredSide: .b)
        #expect(earlierOpen == .failure(.setScore(set: 1, sport: .badminton)))

        // Impossible scores stay invalid.
        let impossible = ResultRules.validateSets(sets((25, 10)), bestOf: 3, sport: .badminton, retiredSide: .b)
        #expect(impossible == .failure(.setScore(set: 1, sport: .badminton)))

        // Nobody can give up after the match is over.
        let over = ResultRules.validateSets(sets((21, 10), (21, 10)), bestOf: 3, sport: .badminton, retiredSide: .b)
        #expect(over == .failure(.retiredAfterMatchEnded))
    }
}
