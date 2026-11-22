import Foundation

/// Elo is kept separately for `Singles` (1v1 + Race) and `Team` (plan.md §2.4).
enum EloGroup: Hashable {
    case singles, team

    init(_ mode: MatchMode) {
        self = mode == .team ? .team : .singles
    }

    /// S2c filter "Mode": "All" shows the Singles Elo.
    init(_ filter: ModeFilter) {
        self = filter == .team ? .team : .singles
    }
}

/// One rating: a player in a sport and mode group.
struct EloKey: Hashable {
    let playerID: UUID
    let sport: Sport
    let group: EloGroup
}

/// A player's rating right after a match ("Elo History").
struct EloPoint: Equatable {
    let date: Date
    let rating: Double
}

/// All ratings, computed from all counting matches in chronological order (plan.md §2.4).
/// Never stored, so editing or deleting a match is reflected automatically.
struct EloTable {
    fileprivate(set) var ratings: [EloKey: Double] = [:]
    fileprivate(set) var matchCounts: [EloKey: Int] = [:]
    fileprivate(set) var history: [EloKey: [EloPoint]] = [:]
    /// Rating change per player and match, for S3.
    fileprivate(set) var changes: [UUID: [UUID: Double]] = [:]

    /// The current rating rounded, `nil` before 3 matches ("Unranked").
    func rating(of player: Player, sport: Sport, group: EloGroup) -> Int? {
        let key = EloKey(playerID: player.id, sport: sport, group: group)
        guard matchCounts[key, default: 0] >= Elo.minimumMatches else { return nil }
        return Int(ratings[key, default: Elo.start].rounded())
    }

    func isRanked(_ player: Player, sport: Sport, group: EloGroup) -> Bool {
        rating(of: player, sport: sport, group: group) != nil
    }

    func history(of player: Player, sport: Sport, group: EloGroup) -> [EloPoint] {
        history[EloKey(playerID: player.id, sport: sport, group: group)] ?? []
    }

    /// Rating changes of one match, by player ID.
    func changes(in match: Match) -> [UUID: Double] {
        changes[match.id] ?? [:]
    }
}

enum Elo {
    static let start = 1000.0
    static let minimumMatches = 3

    /// Expected score `E = 1 / (1 + 10^((Elo_opponent − Elo_me) / 400))`.
    static func expected(_ mine: Double, against theirs: Double) -> Double {
        1 / (1 + pow(10, (theirs - mine) / 400))
    }

    /// K = 40 for a player's first 10 matches in a sport (and group), then 24.
    static func k(matchesPlayed: Int) -> Double {
        matchesPlayed < 10 ? 40 : 24
    }

    static func score(_ outcome: DuelOutcome) -> Double {
        switch outcome {
        case .win: 1
        case .loss: 0
        case .draw: 0.5
        }
    }

    /// "Unranked" before 3 matches.
    static func text(_ rating: Int?) -> String {
        rating.map { "\($0)" } ?? "Unranked"
    }

    /// "+14", "−14" (with a real minus sign), "±0".
    static func changeText(_ change: Double) -> String {
        let rounded = Int(change.rounded())
        if rounded > 0 { return "+\(rounded)" }
        if rounded < 0 { return "\u{2212}\(-rounded)" }
        return "±0"
    }

    /// "Elo" row at the top of "Head to Head". Higher is better; no leader while someone is unranked.
    static func comparisonRow(mine: Int?, theirs: Int?) -> ComparisonRow {
        let leader: Record.Leader? = if let mine, let theirs {
            mine > theirs ? .me : mine < theirs ? .friend : .tied
        } else {
            nil
        }
        return ComparisonRow(title: "Elo", mine: text(mine), theirs: text(theirs), leader: leader)
    }

    /// "By Sport" line: "Elo 1240 vs 1180", "Unranked" if neither has 3 matches yet.
    static func summary(mine: Int?, theirs: Int?) -> String {
        guard mine != nil || theirs != nil else { return "Unranked" }
        return "Elo \(text(mine)) vs \(text(theirs))"
    }

    static func table(for matches: [Match]) -> EloTable {
        var table = EloTable()
        // Same date: the one entered first counts first, so the order never changes between runs.
        let ordered = matches
            .filter(\.countsTowardRecord)
            .sorted { ($0.date, $0.createdAt, $0.id.uuidString) < ($1.date, $1.createdAt, $1.id.uuidString) }
        for match in ordered {
            apply(match, to: &table)
        }
        return table
    }

    // MARK: - One match

    private static func apply(_ match: Match, to table: inout EloTable) {
        let group = EloGroup(match.mode)
        func key(_ participant: MatchParticipant) -> EloKey? {
            participant.player.map { EloKey(playerID: $0.id, sport: match.sport, group: group) }
        }
        // Deleted players have no rating anymore and count as a new player.
        func rating(_ participant: MatchParticipant) -> Double {
            key(participant).flatMap { table.ratings[$0] } ?? start
        }
        func kFactor(_ participant: MatchParticipant) -> Double {
            k(matchesPlayed: key(participant).map { table.matchCounts[$0, default: 0] } ?? 0)
        }

        var deltas: [ObjectIdentifier: Double] = [:]

        switch match.mode {
        case .race:
            // Each duel on its own with K / (participants − 1), changes added up.
            guard match.isValidRace else { return }
            let racers = match.participants
            let share = Double(racers.count - 1)
            for racer in racers {
                guard let player = racer.player else { continue }
                var delta = 0.0
                let outcomes = match.raceDuels(for: player)
                for (other, duel) in zip(racers.filter { $0 !== racer }, outcomes) {
                    delta += kFactor(racer) / share * (score(duel.outcome) - expected(rating(racer), against: rating(other)))
                }
                deltas[ObjectIdentifier(racer)] = delta
            }

        case .oneVsOne, .team:
            guard let result = match.result else { return }
            for side in [Side.a, .b] {
                let mine = match.participants(on: side)
                let theirs = match.participants(on: side.opponent)
                guard !mine.isEmpty, !theirs.isEmpty else { return }
                // Team Elo = average of the players; everyone on the team gets the same change,
                // with the team's average K.
                let myRating = mine.map(rating).reduce(0, +) / Double(mine.count)
                let theirRating = theirs.map(rating).reduce(0, +) / Double(theirs.count)
                let teamK = mine.map(kFactor).reduce(0, +) / Double(mine.count)
                let outcome: DuelOutcome = switch result.outcome {
                case .draw: .draw
                case .win(let winner): winner == side ? .win : .loss
                }
                let delta = teamK * (score(outcome) - expected(myRating, against: theirRating))
                for participant in mine { deltas[ObjectIdentifier(participant)] = delta }
            }
        }

        // Apply after all deltas are known, so everyone uses the ratings from before the match.
        for participant in match.participants {
            guard let key = key(participant), let player = participant.player,
                  let delta = deltas[ObjectIdentifier(participant)] else { continue }
            let new = table.ratings[key, default: start] + delta
            table.ratings[key] = new
            table.matchCounts[key, default: 0] += 1
            table.history[key, default: []].append(EloPoint(date: match.date, rating: new))
            table.changes[match.id, default: [:]][player.id] = delta
        }
    }
}
