import Foundation

/// One bar in "Score Margin": above 0 = you win (plan.md §4 S2c).
struct MarginPoint {
    let match: Match
    /// Sets: point difference over all sets; points and penalties: goal difference.
    let margin: Int
    let outcome: DuelOutcome
}

/// One day in "Activity".
struct ActivityDay: Equatable {
    let date: Date
    let matches: Int
}

/// Both times of one run at a distance (Running chart), `nil` for DNF or not running.
struct RunPoint {
    let date: Date
    let mine: Int?
    let theirs: Int?
}

extension Rivalry {

    /// Each match once, oldest first (team matches have one duel per opponent).
    static func uniqueMatches(_ duels: [Duel]) -> [Match] {
        var seen = Set<UUID>()
        return duels.sorted { $0.date < $1.date }.map(\.match).filter { seen.insert($0.id).inserted }
    }

    // MARK: - Score Margin

    static func margins(_ duels: [Duel], me: Player) -> [MarginPoint] {
        uniqueMatches(duels).compactMap { match in
            guard hasMargin(match.sportType), let mySide = match.side(of: me),
                  let outcome = match.outcome(for: me), let result = match.result else { return nil }
            let difference: Int
            if match.scoringType == .sets {
                difference = match.orderedSets.reduce(0) { $0 + $1.scoreA - $1.scoreB }
            } else {
                guard let a = result.scoreA, let b = result.scoreB else { return nil }
                difference = a - b
            }
            return MarginPoint(match: match, margin: mySide == .a ? difference : -difference, outcome: outcome)
        }
    }

    // MARK: - Activity

    /// Start of the "Activity" calendar: the period start, 12 months for "All".
    static func activityStart(for period: StatsPeriod, now: Date = Date(), calendar: Calendar = .current) -> Date {
        period.since(now: now, calendar: calendar)
            ?? calendar.date(byAdding: .year, value: -1, to: now) ?? now
    }

    /// Weeks (columns) of 7 days from the week containing `start` to the week containing `now`.
    /// Days outside `start...now` are `nil`; the count is the number of matches that day.
    static func activityWeeks(_ duels: [Duel], from start: Date, now: Date = Date(),
                              calendar: Calendar = .current) -> [[ActivityDay?]] {
        var counts: [Date: Int] = [:]
        for match in uniqueMatches(duels) {
            counts[calendar.startOfDay(for: match.date), default: 0] += 1
        }

        let first = calendar.startOfDay(for: start)
        let today = calendar.startOfDay(for: now)
        guard let firstWeek = calendar.dateInterval(of: .weekOfYear, for: first)?.start else { return [] }

        var weeks: [[ActivityDay?]] = []
        var weekStart = firstWeek
        while weekStart <= today {
            let week = (0..<7).map { offset -> ActivityDay? in
                guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart),
                      day >= first, day <= today else { return nil }
                return ActivityDay(date: day, matches: counts[day] ?? 0)
            }
            weeks.append(week)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { break }
            weekStart = next
        }
        return weeks
    }

    // MARK: - Running

    /// Times of both runners per distance, oldest first. Only runs where at least one finished.
    static func runTimes(_ duels: [Duel], me: Player, friend: Player) -> [Int: [RunPoint]] {
        func time(_ match: Match, _ player: Player) -> Int? {
            match.participants.first { $0.player?.id == player.id }.flatMap { $0.dnf ? nil : $0.timeMs }
        }
        var runs: [Int: [RunPoint]] = [:]
        for match in uniqueMatches(duels) where match.scoringType == .time {
            guard let distance = match.distanceMeters else { continue }
            let point = RunPoint(date: match.date, mine: time(match, me), theirs: time(match, friend))
            if point.mine != nil || point.theirs != nil { runs[distance, default: []].append(point) }
        }
        return runs
    }

    /// Distances by number of runs, most first (default chip = most run).
    static func distancesByRuns(_ runs: [Int: [RunPoint]]) -> [Int] {
        runs.keys.sorted { (runs[$0]?.count ?? 0, $1) > (runs[$1]?.count ?? 0, $0) }
    }
}
