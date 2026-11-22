import Foundation

/// One line of the S2c "Head to Head" table: your value, label, friend's value.
struct ComparisonRow: Equatable {
    let title: String
    let mine: String
    let theirs: String
    /// Who has the better value. `nil` if the row isn't a comparison (e.g. draws).
    let leader: Record.Leader?
}

/// Sport-specific "Head to Head" stats for one sport (plan.md §4 S2c, decision 8).
/// Built from the counting duels, so the S2c filters (period, mode) apply.
enum SportComparison {

    static func rows(for sport: SportType, duels: [Duel], me: Player) -> [ComparisonRow] {
        // Team matches have one duel per opponent; count each match once.
        var seen = Set<UUID>()
        let matches = duels.map(\.match).filter { $0.sportType == sport && seen.insert($0.id).inserted }
        guard !matches.isEmpty else { return [] }

        var record = Record()
        for duel in duels where duel.match.sportType == sport { record.add(duel.outcome) }
        var rows = [compare("Wins", record.wins, record.losses)]

        switch sport.scoringType {
        case .sets: rows += setRows(sport, matches, me)
        case .points: rows += pointRows(sport, matches, me, draws: record.draws)
        case .penalties: rows += penaltyRows(matches, me)
        case .fight: rows += fightRows(matches, me, draws: record.draws)
        case .time:
            rows += timeRows(matches, me, draws: record.draws)
            if let friend = duels.first?.opponent, matches.contains(where: { $0.mode == .race }) {
                rows += raceRows(matches.filter { $0.mode == .race }, me, friend, laps: false)
            }
        case .placement:
            if let friend = duels.first?.opponent { rows += raceRows(matches, me, friend, laps: true) }
        case .winLoss: break
        }
        return rows
    }

    // MARK: - Races

    /// "Avg. place" (lower is better), "Podiums" (top 3), "Best lap" (Go-Kart, lower is better).
    private static func raceRows(_ races: [Match], _ me: Player, _ friend: Player, laps: Bool) -> [ComparisonRow] {
        var placesMine: [Int] = [], placesTheirs: [Int] = []
        var lapMine: Int?, lapTheirs: Int?
        for race in races {
            if let place = race.racePlace(of: me) { placesMine.append(place) }
            if let place = race.racePlace(of: friend) { placesTheirs.append(place) }
            for participant in race.participants {
                guard let lap = participant.fastestLapMs else { continue }
                if participant.player?.id == me.id { lapMine = min(lapMine ?? .max, lap) }
                if participant.player?.id == friend.id { lapTheirs = min(lapTheirs ?? .max, lap) }
            }
        }

        func average(_ places: [Int]) -> Double? {
            places.isEmpty ? nil : Double(places.reduce(0, +)) / Double(places.count)
        }
        let avgMine = average(placesMine), avgTheirs = average(placesTheirs)
        var rows = [
            ComparisonRow(title: "Avg. place", mine: avgMine.map(oneDecimal) ?? "–", theirs: avgTheirs.map(oneDecimal) ?? "–",
                          // Lower is better; no place at all loses.
                          leader: leader(-(avgMine ?? 99), -(avgTheirs ?? 99))),
            compare("Podiums", placesMine.filter { $0 <= 3 }.count, placesTheirs.filter { $0 <= 3 }.count),
        ]
        if laps {
            rows.append(ComparisonRow(title: "Best lap",
                                      mine: lapMine.map { TimeText.lap(milliseconds: $0) } ?? "–",
                                      theirs: lapTheirs.map { TimeText.lap(milliseconds: $0) } ?? "–",
                                      leader: leader(-Double(lapMine ?? .max), -Double(lapTheirs ?? .max))))
        }
        return rows
    }

    // MARK: - Sets

    private static func setRows(_ sport: SportType, _ matches: [Match], _ me: Player) -> [ComparisonRow] {
        guard let rules = sport.setRules else { return [] }
        var setsMine = 0, setsTheirs = 0, setsPlayed = 0
        var pointsMine = 0, pointsTheirs = 0
        var extraMine = 0, extraTheirs = 0   // deuce sets (Badminton, Ping Pong) or tiebreaks (Tennis, Padel)

        for match in matches {
            guard let mySide = match.side(of: me) else { continue }
            for set in match.orderedSets {
                let (mine, theirs) = mySide == .a ? (set.scoreA, set.scoreB) : (set.scoreB, set.scoreA)
                pointsMine += mine
                pointsTheirs += theirs
                guard case .won(let winner) = ResultRules.check(
                    SetEntry(scoreA: set.scoreA, scoreB: set.scoreB, tiebreakA: set.tiebreakA, tiebreakB: set.tiebreakB),
                    rules: rules) else { continue }
                setsPlayed += 1
                let iWon = winner == mySide
                if iWon { setsMine += 1 } else { setsTheirs += 1 }

                // A set that went past the normal end: 22:20 in Badminton, 12:10 in Ping Pong, 7:6 in Tennis.
                let wentLong = rules.tiebreak != nil ? set.tiebreakA != nil : max(set.scoreA, set.scoreB) > rules.pointsToWin
                if wentLong { if iWon { extraMine += 1 } else { extraTheirs += 1 } }
            }
        }

        let unit = rules.tiebreak != nil ? "games" : "points"
        let sets = max(1, matches.reduce(0) { $0 + $1.sets.count })
        return [
            compare("Sets won", setsMine, setsTheirs),
            compare(unit == "games" ? "Games won" : "Points won", pointsMine, pointsTheirs),
            compare("Avg. \(unit) per set", Double(pointsMine) / Double(sets), Double(pointsTheirs) / Double(sets),
                    format: oneDecimal),
            compare("Set win rate", rate(setsMine, setsPlayed), rate(setsTheirs, setsPlayed), format: percent),
            compare(rules.tiebreak != nil ? "Tiebreaks won" : "Deuce sets won", extraMine, extraTheirs),
        ]
    }

    // MARK: - Points

    private static func pointRows(_ sport: SportType, _ matches: [Match], _ me: Player, draws: Int) -> [ComparisonRow] {
        var mine = 0, theirs = 0
        var biggestMine: (margin: Int, text: String)?
        var biggestTheirs: (margin: Int, text: String)?

        for match in matches {
            guard let mySide = match.side(of: me), let score = match.orderedSets.first else { continue }
            let (a, b) = mySide == .a ? (score.scoreA, score.scoreB) : (score.scoreB, score.scoreA)
            mine += a
            theirs += b
            if a > b, a - b > (biggestMine?.margin ?? 0) { biggestMine = (a - b, "\(a)–\(b)") }
            if b > a, b - a > (biggestTheirs?.margin ?? 0) { biggestTheirs = (b - a, "\(b)–\(a)") }
        }

        let unit = sport == .football ? "Goals" : "Points"
        let count = Double(max(1, matches.count))
        var rows = [
            compare(unit, mine, theirs),
            compare("Avg. \(unit.lowercased()) per match", Double(mine) / count, Double(theirs) / count, format: oneDecimal),
            ComparisonRow(title: "Biggest win", mine: biggestMine?.text ?? "–", theirs: biggestTheirs?.text ?? "–",
                          leader: leader(Double(biggestMine?.margin ?? 0), Double(biggestTheirs?.margin ?? 0))),
        ]
        if sport.allowsDraw { rows.insert(shared("Draws", draws), at: 0) }
        return rows
    }

    // MARK: - Penalties

    private static func penaltyRows(_ matches: [Match], _ me: Player) -> [ComparisonRow] {
        var goalsMine = 0, goalsTheirs = 0, shotsMine = 0, shotsTheirs = 0
        var suddenDeathMine = 0, suddenDeathTheirs = 0

        for match in matches {
            guard let mySide = match.side(of: me) else { continue }
            for shot in match.penalties {
                if shot.side == mySide {
                    shotsMine += 1
                    if shot.scored { goalsMine += 1 }
                } else {
                    shotsTheirs += 1
                    if shot.scored { goalsTheirs += 1 }
                }
            }
            if match.penalties.contains(where: \.isSuddenDeath) {
                switch match.outcome(for: me) {
                case .win: suddenDeathMine += 1
                case .loss: suddenDeathTheirs += 1
                default: break
                }
            }
        }

        return [
            compare("Goals", goalsMine, goalsTheirs),
            compare("Conversion rate", rate(goalsMine, shotsMine), rate(goalsTheirs, shotsTheirs), format: percent),
            compare("Sudden death wins", suddenDeathMine, suddenDeathTheirs),
        ]
    }

    // MARK: - Fight

    private static func fightRows(_ matches: [Match], _ me: Player, draws: Int) -> [ComparisonRow] {
        var stoppageMine = 0, stoppageTheirs = 0, pointsMine = 0, pointsTheirs = 0
        for match in matches {
            guard let fight = match.fight, let outcome = match.outcome(for: me), outcome != .draw else { continue }
            let byStoppage = fight.method == .ko || fight.method == .tko
            switch (outcome, byStoppage, fight.method == .points) {
            case (.win, true, _): stoppageMine += 1
            case (.loss, true, _): stoppageTheirs += 1
            case (.win, _, true): pointsMine += 1
            case (.loss, _, true): pointsTheirs += 1
            default: break
            }
        }
        // Rounds actually fought: the end round of a stoppage, otherwise all rounds. Same for both.
        let fights = matches.compactMap(\.fight)
        let rounds = fights.map { $0.endRound ?? $0.totalRounds }
        let avgRounds = rounds.isEmpty ? "–" : oneDecimal(Double(rounds.reduce(0, +)) / Double(rounds.count))
        return [
            compare("Wins by KO/TKO", stoppageMine, stoppageTheirs),
            compare("Wins by points", pointsMine, pointsTheirs),
            shared("Draws", draws),
            ComparisonRow(title: "Avg. rounds", mine: avgRounds, theirs: avgRounds, leader: nil),
        ]
    }

    // MARK: - Time

    private static func timeRows(_ matches: [Match], _ me: Player, draws: Int) -> [ComparisonRow] {
        var bestMine: [Int: Int] = [:], bestTheirs: [Int: Int] = [:]
        for match in matches {
            guard let distance = match.distanceMeters, let mySide = match.side(of: me) else { continue }
            if let time = match.participants(on: mySide).first.flatMap({ $0.dnf ? nil : $0.timeMs }) {
                bestMine[distance] = min(bestMine[distance] ?? .max, time)
            }
            if let time = match.participants(on: mySide.opponent).first.flatMap({ $0.dnf ? nil : $0.timeMs }) {
                bestTheirs[distance] = min(bestTheirs[distance] ?? .max, time)
            }
        }

        var rows = [shared("Draws", draws)]
        for distance in Set(bestMine.keys).union(bestTheirs.keys).sorted() {
            let mine = bestMine[distance], theirs = bestTheirs[distance]
            // Lower time is better; a missing time loses.
            let leader = leader(Double(theirs ?? .max), Double(mine ?? .max))
            rows.append(ComparisonRow(title: "Best \(TimeText.distance(distance))",
                                      mine: mine.map { TimeText.text(milliseconds: $0) } ?? "–",
                                      theirs: theirs.map { TimeText.text(milliseconds: $0) } ?? "–",
                                      leader: leader))
        }
        return rows
    }

    // MARK: - Helpers

    private static let oneDecimal: (Double) -> String = { String(format: "%.1f", $0) }
    private static let percent: (Double) -> String = { Rivalry.percentText($0) }

    private static func rate(_ part: Int, _ total: Int) -> Double {
        total > 0 ? Double(part) / Double(total) : 0
    }

    private static func leader(_ mine: Double, _ theirs: Double) -> Record.Leader {
        mine > theirs ? .me : mine < theirs ? .friend : .tied
    }

    private static func compare(_ title: String, _ mine: Int, _ theirs: Int) -> ComparisonRow {
        ComparisonRow(title: title, mine: "\(mine)", theirs: "\(theirs)",
                      leader: leader(Double(mine), Double(theirs)))
    }

    private static func compare(_ title: String, _ mine: Double, _ theirs: Double,
                                format: (Double) -> String) -> ComparisonRow {
        ComparisonRow(title: title, mine: format(mine), theirs: format(theirs), leader: leader(mine, theirs))
    }

    /// A value both share, e.g. draws: shown on both sides, no leader.
    private static func shared(_ title: String, _ value: Int) -> ComparisonRow {
        ComparisonRow(title: title, mine: "\(value)", theirs: "\(value)", leader: nil)
    }
}
