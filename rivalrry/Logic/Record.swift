import Foundation

/// Wins : losses (: draws) from your point of view (plan.md §1).
struct Record: Equatable {
    var wins = 0
    var losses = 0
    var draws = 0

    var matches: Int { wins + losses + draws }

    /// Share of wins among all duels, `nil` without duels.
    var winRate: Double? {
        matches > 0 ? Double(wins) / Double(matches) : nil
    }

    var leader: Leader {
        if wins > losses { return .me }
        if losses > wins { return .friend }
        return .tied
    }

    enum Leader {
        case me, friend, tied
    }

    mutating func add(_ outcome: DuelOutcome) {
        switch outcome {
        case .win: wins += 1
        case .loss: losses += 1
        case .draw: draws += 1
        }
    }
}

/// Which modes count (S2c filter "Mode").
enum ModeFilter: CaseIterable {
    /// "1v1 & Race" – the default record (plan.md §2.3).
    case singles
    case team
    case all

    func includes(_ mode: MatchMode) -> Bool {
        switch self {
        case .singles: mode != .team
        case .team: mode == .team
        case .all: true
        }
    }
}

struct DuelFilter {
    var sport: Sport?
    var mode: ModeFilter = .singles
    /// Only matches on or after this date (S2c filter "Period").
    var since: Date?

    func includes(_ match: Match) -> Bool {
        (sport == nil || match.sport == sport)
            && mode.includes(match.mode)
            && (since.map { match.date >= $0 } ?? true)
    }
}

/// Record and duel calculations between you and one friend.
enum Rivalry {

    /// All counting duels of `me` against `friend`, oldest first.
    static func duels(of me: Player, against friend: Player, in matches: [Match],
                      filter: DuelFilter = DuelFilter()) -> [Duel] {
        matches
            .filter(filter.includes)
            .flatMap { $0.duels(for: me) }
            .filter { $0.opponent?.id == friend.id }
            .sorted { $0.date < $1.date }
    }

    static func record(of me: Player, against friend: Player, in matches: [Match],
                       filter: DuelFilter = DuelFilter()) -> Record {
        var record = Record()
        for duel in duels(of: me, against: friend, in: matches, filter: filter) {
            record.add(duel.outcome)
        }
        return record
    }

    /// One record per sport played, most matches first ("By Sport").
    static func recordsBySport(of me: Player, against friend: Player, in matches: [Match],
                               filter: DuelFilter = DuelFilter()) -> [(sport: Sport, record: Record)] {
        var records: [Sport: Record] = [:]
        for duel in duels(of: me, against: friend, in: matches, filter: filter) {
            records[duel.match.sport, default: Record()].add(duel.outcome)
        }
        return records
            .map { (sport: $0.key, record: $0.value) }
            .sorted {
                // Same count: keep a stable order by name.
                $0.record.matches != $1.record.matches
                    ? $0.record.matches > $1.record.matches
                    : $0.sport.displayName < $1.sport.displayName
            }
    }

    /// The most recent counting match in which both played (S1 "Last match").
    static func lastMatch(of me: Player, with friend: Player, in matches: [Match]) -> Match? {
        matches
            .filter { $0.countsTowardRecord && $0.includes(me) && $0.includes(friend) }
            .max { $0.date < $1.date }
    }
}
