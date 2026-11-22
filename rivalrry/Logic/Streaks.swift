import Foundation

/// Consecutive wins or losses from your point of view. A draw ends every streak.
struct Streak: Equatable {
    enum Kind { case wins, losses }

    let kind: Kind
    let count: Int

    /// "3 wins", "1 loss" (S2c "Current streak", "Longest streak").
    var shortText: String {
        switch kind {
        case .wins: count == 1 ? "1 win" : "\(count) wins"
        case .losses: count == 1 ? "1 loss" : "\(count) losses"
        }
    }

    /// "4 wins in a row" (S1 card, plan.md §4 S1).
    var rowText: String { "\(shortText) in a row" }
}

/// A single win for the S2c "Highlights": the match and how clear it was.
struct WinHighlight {
    let match: Match
    /// Sets: (set difference, point difference); points and penalties: (goal difference, 0).
    let margin: (primary: Int, secondary: Int)

    static func < (lhs: WinHighlight, rhs: WinHighlight) -> Bool {
        lhs.margin < rhs.margin
    }
}

extension Rivalry {

    /// S1 shows a streak from 3 on.
    static let cardStreakMinimum = 3

    /// The streak at the end of the duels, `nil` if the last duel was a draw (or there are none).
    static func currentStreak(_ duels: [Duel]) -> Streak? {
        let sorted = duels.sorted { $0.date < $1.date }
        guard let last = sorted.last?.outcome, last != .draw else { return nil }
        let count = sorted.reversed().prefix { $0.outcome == last }.count
        return Streak(kind: last == .win ? .wins : .losses, count: count)
    }

    /// The most wins in a row, `nil` without a win.
    static func longestWinStreak(_ duels: [Duel]) -> Streak? {
        var longest = 0, current = 0
        for duel in duels.sorted(by: { $0.date < $1.date }) {
            current = duel.outcome == .win ? current + 1 : 0
            longest = max(longest, current)
        }
        return longest > 0 ? Streak(kind: .wins, count: longest) : nil
    }

    /// Streak for the S1 card (default record), only from 3 in a row.
    static func cardStreak(of me: Player, against friend: Player, in matches: [Match]) -> Streak? {
        currentStreak(duels(of: me, against: friend, in: matches))
            .flatMap { $0.count >= cardStreakMinimum ? $0 : nil }
    }

    // MARK: - Highlights

    /// Scoring types with a score margin: sets, points, penalties.
    static func hasMargin(_ sport: SportType) -> Bool {
        [.sets, .points, .penalties].contains(sport.scoringType)
    }

    /// Your wins with their margin, oldest first.
    static func winHighlights(_ duels: [Duel], me: Player) -> [WinHighlight] {
        var seen = Set<UUID>()
        return duels
            .filter { $0.outcome == .win && seen.insert($0.match.id).inserted }
            .compactMap { duel in
                let match = duel.match
                guard hasMargin(match.sportType), let mySide = match.side(of: me),
                      let result = match.result, let a = result.scoreA, let b = result.scoreB else { return nil }
                let primary = mySide == .a ? a - b : b - a
                var secondary = 0
                if match.scoringType == .sets {
                    let points = match.orderedSets.reduce(0) { $0 + $1.scoreA - $1.scoreB }
                    secondary = mySide == .a ? points : -points
                }
                return WinHighlight(match: match, margin: (primary, secondary))
            }
    }

    /// "Closest win": smallest margin; same margin → the more recent one.
    static func closestWin(_ duels: [Duel], me: Player) -> WinHighlight? {
        winHighlights(duels, me: me).min { $0 < $1 || (!($1 < $0) && $0.match.date > $1.match.date) }
    }

    /// "Biggest win": largest margin; same margin → the more recent one.
    static func biggestWin(_ duels: [Duel], me: Player) -> WinHighlight? {
        winHighlights(duels, me: me).max { $0 < $1 || (!($1 < $0) && $0.match.date < $1.match.date) }
    }
}
