import Foundation
import SwiftData

/// Everything entered in S2b Add Match before it is saved. Side A is always you, side B the friend.
struct MatchDraft: Equatable {
    let sport: SportType

    // sets
    var bestOf: Int
    var sets: [SetEntry] = [SetEntry(scoreA: 0, scoreB: 0)]
    /// "Match not finished"
    var isRetired = false
    var retiredSide: Side = .b

    // points
    var scoreA = 0
    var scoreB = 0

    // penalties, in shooting order A, B, A, B … (`true` = goal)
    var penaltyShotsPerSide = ResultRules.defaultPenaltyShots
    var penaltyShots: [Bool] = []

    // fight
    var fightWinner: Side? = .a
    var fightMethod: FightMethod = .points
    var fightRounds = ResultRules.defaultFightRounds
    var fightEndRound = 1

    // time
    var distanceMeters: Int? = 100
    var timeTextA = ""
    var timeTextB = ""
    var dnfA = false
    var dnfB = false

    // "More details"
    var date = Date()
    var note = ""

    static let noteLimit = 200

    /// - Parameter bestOf: default format, e.g. from S9 settings. Falls back to plan.md §2.2.
    init(sport: SportType, bestOf: Int? = nil) {
        self.sport = sport
        let fallback = sport.defaultBestOf ?? 1
        self.bestOf = bestOf.flatMap { sport.bestOfOptions.contains($0) ? $0 : nil } ?? fallback
    }

    // MARK: - Validation

    func validate() -> Result<MatchResult, ResultIssue> {
        switch sport.scoringType {
        case .sets:
            return ResultRules.validateSets(effectiveSets, bestOf: bestOf, sport: sport,
                                            retiredSide: isRetired ? retiredSide : nil)
        case .points:
            return ResultRules.validatePoints(scoreA: scoreA, scoreB: scoreB, sport: sport)
        case .penalties:
            return ResultRules.validatePenalties(penaltyEntries, shotsPerSide: penaltyShotsPerSide)
        case .fight:
            return ResultRules.validateFight(fightEntry)
        case .time:
            return ResultRules.validateTime(timeA: TimeText.milliseconds(from: timeTextA), dnfA: dnfA,
                                            timeB: TimeText.milliseconds(from: timeTextB), dnfB: dnfB,
                                            distanceMeters: distanceMeters)
        case .placement, .winLoss:
            return .failure(.invalidFormat)
        }
    }

    var isValid: Bool { (try? validate().get()) != nil }

    /// Live preview: "You win 2–1", "Max wins 3–2", "Draw" (plan.md §4 S2b).
    func previewText(friendName: String) -> String? {
        guard let result = try? validate().get() else { return nil }
        switch result.outcome {
        case .draw:
            return "Draw"
        case .win(let side):
            var text = side == .a ? "You win" : "\(friendName) wins"
            if let a = result.scoreA, let b = result.scoreB {
                text += side == .a ? " \(a)–\(b)" : " \(b)–\(a)"
            }
            return text
        }
    }

    // MARK: - Sets

    /// Whether another set can be added: the match isn't decided and the format allows more sets.
    var canAddSet: Bool {
        guard sets.count < bestOf, !isRetired, let rules = sport.setRules else { return false }
        let needed = bestOf / 2 + 1
        var wonA = 0, wonB = 0
        for set in effectiveSets {
            switch ResultRules.check(set, rules: rules) {
            case .won(.a): wonA += 1
            case .won(.b): wonB += 1
            default: return false   // finish the open set first
            }
        }
        return wonA < needed && wonB < needed
    }

    /// The sets as they count: a tiebreak only stays on a 7:6 set. If the score was changed
    /// after entering a tiebreak, the hidden tiebreak value must not block saving.
    var effectiveSets: [SetEntry] {
        sets.map { needsTiebreakField($0) ? $0 : SetEntry(scoreA: $0.scoreA, scoreB: $0.scoreB) }
    }

    /// A tiebreak field is shown for a 7:6 set in Tennis/Padel.
    func needsTiebreakField(_ set: SetEntry) -> Bool {
        guard let rules = sport.setRules, rules.tiebreak != nil else { return false }
        return max(set.scoreA, set.scoreB) == rules.pointsToWin + 1
            && min(set.scoreA, set.scoreB) == rules.pointsToWin
    }

    // MARK: - Penalties

    var penaltyEntries: [PenaltyEntry] {
        penaltyShots.enumerated().map { index, scored in
            PenaltyEntry(side: index.isMultiple(of: 2) ? .a : .b, scored: scored)
        }
    }

    enum ShotState: Equatable {
        case scored, missed
        /// The next shot to enter.
        case next
        case empty
    }

    /// Shot state for `round` (0-based) and `side`.
    func shotState(round: Int, side: Side) -> ShotState {
        let index = round * 2 + (side == .a ? 0 : 1)
        if index < penaltyShots.count { return penaltyShots[index] ? .scored : .missed }
        return index == penaltyShots.count && !isValid ? .next : .empty
    }

    /// Tapping a shot: the next one becomes a goal; a goal becomes a miss;
    /// a miss becomes a goal again, except the last shot, which is removed.
    mutating func tapShot(round: Int, side: Side) {
        let index = round * 2 + (side == .a ? 0 : 1)
        if index == penaltyShots.count, !isValid {
            penaltyShots.append(true)
        } else if index < penaltyShots.count {
            if penaltyShots[index] {
                penaltyShots[index] = false
            } else if index == penaltyShots.count - 1 {
                penaltyShots.removeLast()
            } else {
                penaltyShots[index] = true
            }
        }
    }

    /// Regular rounds, plus sudden death rounds while it's still tied.
    var penaltyRounds: Int {
        let taken = penaltyShots.count
        let roundsTaken = (taken + 1) / 2
        var rounds = max(penaltyShotsPerSide, roundsTaken)
        if taken >= penaltyShotsPerSide * 2, taken.isMultiple(of: 2),
           case .failure(.shootoutNotDecided) = validate() {
            rounds = roundsTaken + 1
        }
        return rounds
    }

    // MARK: - Fight

    var fightEntry: FightEntry {
        FightEntry(winnerSide: fightWinner, method: fightMethod, totalRounds: fightRounds,
                   endRound: fightMethod == .points ? nil : min(fightEndRound, fightRounds))
    }

    // MARK: - Saving

    /// Creates and inserts the match. Phase 1–2: status `Local`, counts immediately.
    @discardableResult
    func insertMatch(me: Player, friend: Player, into context: ModelContext) -> Match {
        let match = Match(sportType: sport, mode: .oneVsOne, date: date, status: .local, createdBy: me)
        context.insert(match)
        match.participants = [MatchParticipant(player: me, side: .a), MatchParticipant(player: friend, side: .b)]
        write(to: match, context: context)
        return match
    }

    /// S3 "Edit": overwrites the result of an existing match.
    func apply(to match: Match, context: ModelContext) {
        // Replace the old details instead of patching them.
        for set in match.sets { context.delete(set) }
        for shot in match.penalties { context.delete(shot) }
        if let fight = match.fight { context.delete(fight) }
        match.sets = []
        match.penalties = []
        match.fight = nil
        match.bestOf = nil
        match.retiredSide = nil
        match.penaltyShotsPerSide = nil
        match.distanceMeters = nil
        for participant in match.participants {
            participant.timeMs = nil
            participant.dnf = false
        }

        match.date = date
        match.updatedAt = Date()
        match.version += 1
        write(to: match, context: context)
    }

    private func write(to match: Match, context: ModelContext) {
        match.note = note.isEmpty ? nil : String(note.prefix(Self.noteLimit))
        let mine = match.participants(on: .a).first
        let theirs = match.participants(on: .b).first

        switch sport.scoringType {
        case .sets:
            match.bestOf = bestOf
            match.retiredSide = isRetired ? retiredSide : nil
            match.sets = sets.enumerated().map { index, set in
                let tiebreak = needsTiebreakField(set)
                return SetScore(index: index, scoreA: set.scoreA, scoreB: set.scoreB,
                                tiebreakA: tiebreak ? set.tiebreakA : nil,
                                tiebreakB: tiebreak ? set.tiebreakB : nil)
            }
        case .points:
            match.sets = [SetScore(index: 0, scoreA: scoreA, scoreB: scoreB)]
        case .penalties:
            match.penaltyShotsPerSide = penaltyShotsPerSide
            match.penalties = penaltyEntries.enumerated().map { index, shot in
                PenaltyShot(index: index, side: shot.side, scored: shot.scored,
                            isSuddenDeath: ResultRules.isSuddenDeath(index: index, shotsPerSide: penaltyShotsPerSide))
            }
        case .fight:
            let entry = fightEntry
            match.fight = FightDetail(winnerSide: entry.winnerSide, method: entry.method,
                                      endRound: entry.endRound, totalRounds: entry.totalRounds)
        case .time:
            match.distanceMeters = distanceMeters
            mine?.dnf = dnfA
            mine?.timeMs = dnfA ? nil : TimeText.milliseconds(from: timeTextA)
            theirs?.dnf = dnfB
            theirs?.timeMs = dnfB ? nil : TimeText.milliseconds(from: timeTextB)
        case .placement, .winLoss:
            break
        }
    }

    // MARK: - Editing

    /// Loads a saved match back into the form (S3 "Edit"). Side A stays side A.
    init(match: Match) {
        self.init(sport: match.sportType)
        date = match.date
        note = match.note ?? ""

        switch match.scoringType {
        case .sets:
            bestOf = match.bestOf ?? bestOf
            sets = match.orderedSets.map {
                SetEntry(scoreA: $0.scoreA, scoreB: $0.scoreB, tiebreakA: $0.tiebreakA, tiebreakB: $0.tiebreakB)
            }
            if sets.isEmpty { sets = [SetEntry(scoreA: 0, scoreB: 0)] }
            isRetired = match.retiredSide != nil
            retiredSide = match.retiredSide ?? .b
        case .points:
            scoreA = match.orderedSets.first?.scoreA ?? 0
            scoreB = match.orderedSets.first?.scoreB ?? 0
        case .penalties:
            penaltyShotsPerSide = match.penaltyShotsPerSide ?? ResultRules.defaultPenaltyShots
            penaltyShots = match.orderedPenalties.map(\.scored)
        case .fight:
            if let fight = match.fight {
                fightWinner = fight.winnerSide
                fightMethod = fight.method
                fightRounds = fight.totalRounds
                fightEndRound = fight.endRound ?? 1
            }
        case .time:
            distanceMeters = match.distanceMeters
            let a = match.participants(on: .a).first
            let b = match.participants(on: .b).first
            dnfA = a?.dnf ?? false
            dnfB = b?.dnf ?? false
            timeTextA = a?.timeMs.map { TimeText.text(milliseconds: $0) } ?? ""
            timeTextB = b?.timeMs.map { TimeText.text(milliseconds: $0) } ?? ""
        case .placement, .winLoss:
            break
        }
    }
}

extension TimeText {
    /// Parses "12.34", "4:05.2" or "1:02:03.40" into milliseconds. `nil` if it can't be read.
    static func milliseconds(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count), let secondsPart = parts.last,
              let seconds = Double(secondsPart), seconds >= 0 else { return nil }
        var minutes = 0, hours = 0
        if parts.count >= 2 {
            guard let m = Int(parts[parts.count - 2]), m >= 0, seconds < 60 else { return nil }
            minutes = m
        }
        if parts.count == 3 {
            guard let h = Int(parts[0]), h >= 0, minutes < 60 else { return nil }
            hours = h
        }
        return hours * 3_600_000 + minutes * 60_000 + Int((seconds * 1000).rounded())
    }

    /// "60 m", "1 km", "10 km", "1500 m".
    static func distance(_ meters: Int) -> String {
        meters >= 1000 && meters.isMultiple(of: 1000) ? "\(meters / 1000) km" : "\(meters) m"
    }
}
