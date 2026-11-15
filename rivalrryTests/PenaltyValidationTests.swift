import Testing
@testable import rivalrry

/// Penalty shootout rules from plan.md §2.2.
struct PenaltyValidationTests {

    /// Builds alternating shots A, B, A, B … from a string: "x" = scored, "o" = missed.
    private func shots(_ pattern: String) -> [PenaltyEntry] {
        pattern.filter { $0 != " " }.enumerated().map { index, char in
            PenaltyEntry(side: index.isMultiple(of: 2) ? .a : .b, scored: char == "x")
        }
    }

    private func validate(_ pattern: String, shotsPerSide: Int = 5) -> Result<MatchResult, ResultIssue> {
        ResultRules.validatePenalties(shots(pattern), shotsPerSide: shotsPerSide)
    }

    @Test func fullShootout() {
        // A: 4 of 5, B: 3 of 5.
        #expect(validate("xx xo xx ox xo") == .success(MatchResult(outcome: .win(.a), scoreA: 4, scoreB: 3)))
    }

    @Test func endsEarlyWhenOneSideCantCatchUp() {
        // After 3 rounds A leads 3:0, B has 2 shots left → over.
        #expect(validate("xo xo xo") == .success(MatchResult(outcome: .win(.a), scoreA: 3, scoreB: 0)))
        // A misses the 4th shot: 3:1 with B having 2 left, not over yet.
        #expect(validate("xo xo xx o") == .failure(.shootoutNotDecided))
        // A misses the 4th shot: 1:3 with A having 1 left → over before B's 4th shot.
        #expect(validate("ox xx ox o") == .success(MatchResult(outcome: .win(.b), scoreA: 1, scoreB: 3)))
    }

    @Test func noShotsAfterDecision() {
        #expect(validate("xo xo xo x") == .failure(.shotsAfterDecision))
    }

    @Test func suddenDeath() {
        // 3:3 after 5 rounds, then A scores and B misses.
        #expect(validate("xx xo ox xx oo xo") == .success(MatchResult(outcome: .win(.a), scoreA: 4, scoreB: 3)))
        // Both score in round 6, B wins round 7.
        #expect(validate("xx xo ox xx oo xx ox") == .success(MatchResult(outcome: .win(.b), scoreA: 4, scoreB: 5)))
        // Only A has shot in sudden death: not decided.
        #expect(validate("xx xo ox xx oo x") == .failure(.shootoutNotDecided))
        // Both miss: continue.
        #expect(validate("xx xo ox xx oo oo") == .failure(.shootoutNotDecided))
    }

    @Test func suddenDeathFlag() {
        #expect(!ResultRules.isSuddenDeath(index: 9, shotsPerSide: 5))
        #expect(ResultRules.isSuddenDeath(index: 10, shotsPerSide: 5))
        #expect(ResultRules.isSuddenDeath(index: 6, shotsPerSide: 3))
    }

    @Test func otherShotCounts() {
        #expect(validate("xo xo", shotsPerSide: 3) == .success(MatchResult(outcome: .win(.a), scoreA: 2, scoreB: 0)))
        #expect(validate("xo xo", shotsPerSide: 10) == .failure(.shootoutNotDecided))
        #expect(validate("xo", shotsPerSide: 4) == .failure(.invalidShotCount))
    }

    @Test func shotsMustAlternate() {
        let wrong = [PenaltyEntry(side: .a, scored: true), PenaltyEntry(side: .a, scored: true)]
        #expect(ResultRules.validatePenalties(wrong, shotsPerSide: 5) == .failure(.invalidShotOrder))
        let startsWithB = [PenaltyEntry(side: .b, scored: true)]
        #expect(ResultRules.validatePenalties(startsWithB, shotsPerSide: 5) == .failure(.invalidShotOrder))
    }

    @Test func emptyShootout() {
        #expect(validate("") == .failure(.shootoutNotDecided))
    }
}
