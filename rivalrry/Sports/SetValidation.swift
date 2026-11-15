import Foundation

/// One set as entered. `tiebreakA`/`tiebreakB` only for a 7:6 set.
struct SetEntry: Equatable {
    var scoreA: Int
    var scoreB: Int
    var tiebreakA: Int? = nil
    var tiebreakB: Int? = nil
}

/// State of a single set.
enum SetCheck: Equatable {
    case won(Side)
    /// Score can still be reached but nobody has won yet (e.g. 21:20).
    case unfinished
    /// 7:6 without a (finished) tiebreak.
    case needsTiebreak
    case invalidScore
    case invalidTiebreak
    case tiebreakNotAllowed
}

extension ResultRules {

    /// Checks a sets result (plan.md §2.2).
    /// - Parameter retiredSide: Side that gave up ("Match not finished"). The last set may then be unfinished.
    static func validateSets(_ sets: [SetEntry], bestOf: Int, sport: SportType,
                             retiredSide: Side? = nil) -> Result<MatchResult, ResultIssue> {
        guard let rules = sport.setRules, sport.bestOfOptions.contains(bestOf) else {
            return .failure(.invalidFormat)
        }
        let needed = bestOf / 2 + 1
        var wonA = 0, wonB = 0

        for (index, set) in sets.enumerated() {
            let number = index + 1
            guard wonA < needed, wonB < needed else { return .failure(.tooManySets) }
            let mayBeUnfinished = retiredSide != nil && index == sets.count - 1

            switch check(set, rules: rules) {
            case .won(.a): wonA += 1
            case .won(.b): wonB += 1
            case .unfinished:
                if !mayBeUnfinished { return .failure(.setScore(set: number, sport: sport)) }
            case .needsTiebreak:
                if !mayBeUnfinished { return .failure(.tiebreakMissing(set: number)) }
            case .invalidScore:
                return .failure(.setScore(set: number, sport: sport))
            case .invalidTiebreak:
                return .failure(.invalidTiebreak(set: number, sport: sport))
            case .tiebreakNotAllowed:
                return .failure(.tiebreakNotAllowed(set: number, sport: sport))
            }
        }

        if let retiredSide {
            // Giving up is only possible while the match is still open.
            guard wonA < needed, wonB < needed else { return .failure(.retiredAfterMatchEnded) }
            return .success(MatchResult(outcome: .win(retiredSide.opponent), scoreA: wonA, scoreB: wonB))
        }
        guard !sets.isEmpty else { return .failure(.noSets) }
        if wonA == needed { return .success(MatchResult(outcome: .win(.a), scoreA: wonA, scoreB: wonB)) }
        if wonB == needed { return .success(MatchResult(outcome: .win(.b), scoreA: wonA, scoreB: wonB)) }
        return .failure(.matchNotDecided(setsNeeded: needed))
    }

    /// Checks a single set against the sport's rules.
    static func check(_ set: SetEntry, rules: SetRules) -> SetCheck {
        let hasTiebreak = set.tiebreakA != nil || set.tiebreakB != nil

        // Tiebreak set, e.g. 7:6 in Tennis/Padel.
        if let tiebreak = rules.tiebreak,
           max(set.scoreA, set.scoreB) == rules.pointsToWin + 1,
           min(set.scoreA, set.scoreB) == rules.pointsToWin {
            let leader: Side = set.scoreA > set.scoreB ? .a : .b
            guard let tiebreakA = set.tiebreakA, let tiebreakB = set.tiebreakB else { return .needsTiebreak }
            switch race(tiebreakA, tiebreakB, toWin: tiebreak.pointsToWin, winBy: tiebreak.winBy, cap: nil) {
            case .won(let side): return side == leader ? .won(side) : .invalidTiebreak
            case .unfinished: return .needsTiebreak
            default: return .invalidTiebreak
            }
        }
        if hasTiebreak { return .tiebreakNotAllowed }
        return race(set.scoreA, set.scoreB, toWin: rules.pointsToWin, winBy: rules.winBy, cap: rules.maxPoints)
    }

    /// First to `toWin` with a lead of `winBy`. At `cap` the next point wins (Badminton 30:29).
    private static func race(_ a: Int, _ b: Int, toWin: Int, winBy: Int, cap: Int?) -> SetCheck {
        guard a >= 0, b >= 0 else { return .invalidScore }
        let high = max(a, b), low = min(a, b)
        let leader: Side = a > b ? .a : .b
        let lead = high - low

        if let cap, high > cap || (high == cap && lead == 0) { return .invalidScore }
        if high < toWin { return .unfinished }
        if high == toWin { return lead >= winBy ? .won(leader) : .unfinished }
        // Past `toWin`: the set ends exactly when the lead reaches `winBy`, or at the cap.
        if lead == winBy { return .won(leader) }
        if lead > winBy { return .invalidScore }
        if let cap, high == cap { return .won(leader) }
        return .unfinished
    }
}
