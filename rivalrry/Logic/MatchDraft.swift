import Foundation
import SwiftData

/// Everything entered in S2b Add Match before it is saved. Side A is always you, side B the friend.
struct MatchDraft: Equatable {
    let sport: SportType

    // mode & participants (Phase 2). In `Team` mode you and the friend are opponents;
    // `partners` play with you (side A), `opponents` with the friend (side B).
    var mode: MatchMode = .oneVsOne
    var partners: [Player] = []
    var opponents: [Player] = []
    /// Editing a saved team match keeps its teams (only the result can change).
    var teamsLocked = false

    // races (Phase 2)
    /// Go-Kart: everyone incl. you and the friend, in finishing order.
    var racers: [RaceEntry] = []
    /// Running: runners beyond you and the friend. With any of them, the run becomes a `Race`.
    var extraRunners: [RaceEntry] = []

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
        if mode == .team, let issue = teamIssue { return .failure(issue) }
        if isRace {
            // Races have no sides; the result is your place (see `raceText`).
            if let issue = raceIssue { return .failure(issue) }
            return .success(MatchResult(outcome: .draw))
        }
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
    /// In `Team` mode: "You win 2–1" / "Max & Lukas win 2–1".
    func previewText(friendName: String) -> String? {
        if isRace { return raceIssue == nil ? raceText : nil }
        guard let result = try? validate().get() else { return nil }
        switch result.outcome {
        case .draw:
            return "Draw"
        case .win(let side):
            let theirName = mode == .team ? teamBName(friendName: friendName) : friendName
            var text = side == .a ? "You win" : "\(theirName) \(mode == .team && !opponents.isEmpty ? "win" : "wins")"
            if let a = result.scoreA, let b = result.scoreB {
                text += side == .a ? " \(a)–\(b)" : " \(b)–\(a)"
            }
            return text
        }
    }

    // MARK: - Team

    /// Whether the sport can be played in teams (plan.md §2.1).
    var allowsTeams: Bool { sport.teamSizes != nil }

    /// Team rules: both teams the same size, size allowed for the sport (plan.md §4 S2b).
    var teamIssue: ResultIssue? {
        guard let sizes = sport.teamSizes else { return .invalidFormat }
        let a = partners.count + 1, b = opponents.count + 1
        if a != b { return .teamsUnequal }
        if !sizes.contains(a) { return .teamSize(sizes) }
        return nil
    }

    /// "You & Tom" for 2 players, "Your team" for more.
    var teamAName: String {
        partners.count == 1 ? "You & \(partners[0].shortName)" : partners.isEmpty ? "You" : "Your team"
    }

    /// "Max & Lukas" for 2 players, "Max's team" for more.
    func teamBName(friendName: String) -> String {
        opponents.count == 1 ? "\(friendName) & \(opponents[0].shortName)"
            : opponents.isEmpty ? friendName : "\(friendName)'s team"
    }

    /// Column labels for the result entry: "You" / "Max", or the team names.
    func names(friendName: String) -> (a: String, b: String) {
        mode == .team ? (teamAName, teamBName(friendName: friendName)) : ("You", friendName)
    }

    /// Players that can still join a team or race: not you, not the friend, not already picked, not archived.
    func availablePlayers(from players: [Player], friend: Player) -> [Player] {
        let taken = Set(partners.map(\.id) + opponents.map(\.id) + [friend.id]
                        + racers.map(\.player.id) + extraRunners.map(\.player.id))
        return players.filter { !$0.isMe && !$0.isArchived && !taken.contains($0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: - Races

    /// Go-Kart is always a race; Running becomes one with a third runner (plan.md §2.2).
    var isRace: Bool {
        sport.scoringType == .placement || (sport.scoringType == .time && !extraRunners.isEmpty)
    }

    /// Go-Kart starts with you and the friend.
    mutating func setUpRace(me: Player, friend: Player) {
        if sport.scoringType == .placement, racers.isEmpty {
            racers = [RaceEntry(player: me), RaceEntry(player: friend)]
        }
    }

    /// DNF racers always finish last, in the order they were marked.
    mutating func sortDNFLast() {
        racers = racers.filter { !$0.dnf } + racers.filter(\.dnf)
    }

    var raceIssue: ResultIssue? {
        switch sport.scoringType {
        case .placement:
            if !(2...12).contains(racers.count) { return .raceSize }
            if racers.contains(where: { !$0.lapText.isEmpty && TimeText.milliseconds(from: $0.lapText) == nil }) {
                return .invalidLapTime
            }
            return nil
        case .time:
            if 2 + extraRunners.count > 12 { return .raceSize }
            guard let distanceMeters, distanceMeters > 0 else { return .invalidDistance }
            let mineOK = dnfA || (TimeText.milliseconds(from: timeTextA) ?? 0) > 0
            let theirsOK = dnfB || (TimeText.milliseconds(from: timeTextB) ?? 0) > 0
            let extrasOK = extraRunners.allSatisfy { $0.dnf || (TimeText.milliseconds(from: $0.timeText) ?? 0) > 0 }
            return mineOK && theirsOK && extrasOK ? nil : .missingTime
        default:
            return nil
        }
    }

    /// Your place in the race, `nil` for DNF.
    var myRacePlace: Int? {
        switch sport.scoringType {
        case .placement:
            guard let mine = racers.firstIndex(where: \.player.isMe), !racers[mine].dnf else { return nil }
            return racers[..<mine].filter { !$0.dnf }.count + 1
        case .time:
            guard !dnfA, let mine = TimeText.milliseconds(from: timeTextA) else { return nil }
            let others = [dnfB ? nil : TimeText.milliseconds(from: timeTextB)]
                + extraRunners.map { $0.dnf ? nil : TimeText.milliseconds(from: $0.timeText) }
            return 1 + others.compactMap { $0 }.filter { $0 < mine }.count
        default:
            return nil
        }
    }

    var raceSize: Int { sport.scoringType == .placement ? racers.count : 2 + extraRunners.count }

    /// Live preview for races: "You finish 2nd of 4", "You didn't finish".
    var raceText: String {
        guard let place = myRacePlace else { return "You didn't finish" }
        return "You finish \(Ordinal.text(place)) of \(raceSize)"
    }

    /// Creates the race participants: no sides, places from the order (Go-Kart) or the times (Running).
    private func raceParticipants(me: Player, friend: Player) -> [MatchParticipant] {
        switch sport.scoringType {
        case .placement:
            var place = 0
            return racers.map { racer in
                if !racer.dnf { place += 1 }
                return MatchParticipant(player: racer.player, place: racer.dnf ? nil : place,
                                        fastestLapMs: racer.lapText.isEmpty ? nil : TimeText.milliseconds(from: racer.lapText),
                                        dnf: racer.dnf)
            }
        default:
            let runners = [RaceEntry(player: me, timeText: timeTextA, dnf: dnfA),
                           RaceEntry(player: friend, timeText: timeTextB, dnf: dnfB)] + extraRunners
            return runners.map {
                MatchParticipant(player: $0.player, timeMs: $0.dnf ? nil : TimeText.milliseconds(from: $0.timeText),
                                 dnf: $0.dnf)
            }
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
        let match = Match(sportType: sport, mode: isRace ? .race : mode, date: date, status: .local, createdBy: me)
        context.insert(match)
        if isRace {
            match.participants = raceParticipants(me: me, friend: friend)
            match.distanceMeters = sport.scoringType == .time ? distanceMeters : nil
            match.note = note.isEmpty ? nil : String(note.prefix(Self.noteLimit))
            return match
        }
        match.participants = [MatchParticipant(player: me, side: .a), MatchParticipant(player: friend, side: .b)]
        if mode == .team {
            match.participants += partners.map { MatchParticipant(player: $0, side: .a) }
                + opponents.map { MatchParticipant(player: $0, side: .b) }
        }
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
    /// - Parameter friend: the friend whose page the match was opened from (side B).
    init(match: Match, friend: Player? = nil) {
        self.init(sport: match.sportType)
        date = match.date
        note = match.note ?? ""
        mode = match.mode
        if match.mode == .team {
            teamsLocked = true
            let mine = match.participants(on: .a).compactMap(\.player)
            let theirs = match.participants(on: .b).compactMap(\.player)
            partners = mine.filter { !$0.isMe }
            // Everyone on side B except one player who stands for "the friend".
            let anchor = theirs.first { $0.id == friend?.id } ?? theirs.first
            opponents = theirs.filter { $0.id != anchor?.id }
        }

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

    /// Lap time with thousandths, as entered: "1:01.870" (plan.md §2.2: mm:ss.SSS).
    static func lap(milliseconds ms: Int) -> String {
        let minutes = ms / 60_000, seconds = (ms / 1000) % 60, thousandths = ms % 1000
        return String(format: "%d:%02d.%03d", minutes, seconds, thousandths)
    }

    /// "60 m", "1 km", "10 km", "1500 m".
    static func distance(_ meters: Int) -> String {
        meters >= 1000 && meters.isMultiple(of: 1000) ? "\(meters / 1000) km" : "\(meters) m"
    }
}

/// One racer while entering a race (Go-Kart or Running with 3+ runners).
struct RaceEntry: Equatable, Identifiable {
    let player: Player
    var timeText = ""
    /// Go-Kart: optional fastest lap, m:ss.SSS.
    var lapText = ""
    var dnf = false

    var id: UUID { player.id }
}
