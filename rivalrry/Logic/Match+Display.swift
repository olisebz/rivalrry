import Foundation
import SwiftData

extension Match {
    /// Win, loss or draw from `player`'s point of view. `nil` without a valid result.
    /// Race: 1st place alone = win, shared 1st place = draw, otherwise loss.
    func outcome(for player: Player) -> DuelOutcome? {
        if mode == .race {
            guard isValidRace, includes(player) else { return nil }
            let place = racePlace(of: player)
            guard place == 1 else { return .loss }
            let firsts = participants.filter { racePlace(of: $0) == 1 }.count
            return firsts > 1 ? .draw : .win
        }
        guard let mySide = side(of: player), let result else { return nil }
        switch result.outcome {
        case .draw: return .draw
        case .win(let side): return side == mySide ? .win : .loss
        }
    }

    /// Result from `player`'s point of view, own score first: "2 – 1", "KO", "12.34 – 12.90".
    func scoreText(for player: Player) -> String {
        // Race: "2nd of 4", or "DNF".
        if mode == .race {
            guard isValidRace, includes(player) else { return "–" }
            guard let place = racePlace(of: player) else { return "DNF" }
            return "\(Ordinal.text(place)) of \(participants.count)"
        }
        guard let mySide = side(of: player), let result else { return "–" }
        let flip = mySide == .b

        switch scoringType {
        case .sets, .points, .penalties:
            guard let a = result.scoreA, let b = result.scoreB else { return "–" }
            return flip ? "\(b) – \(a)" : "\(a) – \(b)"
        case .fight:
            guard let fight else { return "–" }
            if case .draw = result.outcome { return "Draw" }
            return fight.method.displayName
        case .time:
            let mine = participants(on: mySide).first
            let theirs = participants(on: mySide.opponent).first
            return "\(TimeText.text(for: mine)) – \(TimeText.text(for: theirs))"
        case .winLoss:
            switch result.outcome {
            case .draw: return "Draw"
            case .win(let side): return side == mySide ? "Win" : "Loss"
            }
        case .placement:
            return "–"
        }
    }

    /// Second row line: "Nov 12 · Best of 3".
    func detailText(now: Date = Date()) -> String {
        var parts = [MatchDate.text(for: date, now: now)]
        if mode == .team { parts.append(teamFormat) }
        if mode == .race { parts.append("\(participants.count) racers") }
        if scoringType == .time, let distanceMeters { parts.append(TimeText.distance(distanceMeters)) }
        if scoringType == .sets, let bestOf { parts.append("Best of \(bestOf)") }
        return parts.joined(separator: " · ")
    }
}

extension Match {
    /// "2v2", "5v5" for team matches.
    var teamFormat: String {
        "\(participants(on: .a).count)v\(participants(on: .b).count)"
    }
}

extension Rivalry {

    /// "Together": matches where you and `friend` were on the same team (plan.md §4 S2a, decision 9).
    static func togetherRecord(of me: Player, with friend: Player, in matches: [Match],
                               filter: DuelFilter = DuelFilter(mode: .team)) -> Record {
        var record = Record()
        for match in matches where match.mode == .team && match.countsTowardRecord
            && (filter.sport == nil || match.sport == filter.sport)
            && (filter.since.map { match.date >= $0 } ?? true) {
            guard let mySide = match.side(of: me), match.side(of: friend) == mySide,
                  let outcome = match.outcome(for: me) else { continue }
            record.add(outcome)
        }
        return record
    }
}

extension FightMethod {
    /// Texts from plan.md §2.2.
    var displayName: String {
        switch self {
        case .ko: "KO"
        case .tko: "TKO"
        case .points: "Points"
        case .retirement: "Retirement"
        }
    }
}

enum MatchDate {
    private static let sameYear = formatter("MMM d")
    private static let otherYear = formatter("MMM d, yyyy")

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = format
        return formatter
    }

    /// "Nov 12", or "Nov 12, 2025" for another year.
    static func text(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let isSameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let formatter = isSameYear ? sameYear : otherYear
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }
}

enum TimeText {
    /// h:mm:ss.SS, shortened: "12.34", "4:05.20", "1:02:03.40". "DNF" if not finished.
    static func text(for participant: MatchParticipant?) -> String {
        guard let participant else { return "–" }
        if participant.dnf { return "DNF" }
        guard let ms = participant.timeMs else { return "–" }
        return text(milliseconds: ms)
    }

    static func text(milliseconds ms: Int) -> String {
        let hundredths = (ms % 1000) / 10
        let totalSeconds = ms / 1000
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600
        let fraction = String(format: "%02d", hundredths)
        if hours > 0 { return String(format: "%d:%02d:%02d.", hours, minutes, seconds) + fraction }
        if minutes > 0 { return String(format: "%d:%02d.", minutes, seconds) + fraction }
        return "\(seconds)." + fraction
    }
}

extension Record {
    /// Share of wins among decided duels, for the bar in the S2 header. `nil` without decided duels.
    var winShare: Double? {
        let decided = wins + losses
        return decided > 0 ? Double(wins) / Double(decided) : nil
    }
}

extension Rivalry {

    /// All matches you and `friend` played in (any mode and status), newest first.
    static func matches(of me: Player, with friend: Player, in matches: [Match],
                        sport: Sport? = nil) -> [Match] {
        matches
            .filter { $0.includes(me) && $0.includes(friend) && (sport == nil || $0.sport == sport) }
            .sorted { $0.date > $1.date }
    }

    /// Sports you played with `friend`, most matches first (S2 filter chips).
    static func sportsPlayed(of me: Player, with friend: Player, in allMatches: [Match]) -> [Sport] {
        Sport.byCount(in: matches(of: me, with: friend, in: allMatches))
    }

    /// "Delete Friend": deletes matches no other friends took part in.
    /// Other matches keep the friend as "Deleted Player" (plan.md §4 S2).
    static func delete(_ friend: Player, in context: ModelContext) {
        for participation in friend.participations {
            guard let match = participation.match else { continue }
            let others = match.participants.filter {
                $0.player?.id != friend.id && $0.player?.isMe == false
            }
            if others.isEmpty { context.delete(match) }
        }
        context.delete(friend)
    }
}

extension Match {
    /// Who `player` played against: "vs Max", "vs Max & Lukas", "Race · 4 racers".
    func opponentsText(for player: Player) -> String {
        if mode == .race { return "Race · \(participants.count) racers" }
        guard let mySide = side(of: player) else { return "" }
        let names = participants(on: mySide.opponent)
            .map { $0.player?.shortName ?? "Deleted Player" }
            .sorted()
        return "vs " + names.joined(separator: " & ")
    }
}

extension Sport {
    /// The sports of these matches, most played first, then by name (sport chips in "See all").
    static func byCount(in matches: [Match]) -> [Sport] {
        var counts: [Sport: Int] = [:]
        for match in matches {
            counts[match.sport, default: 0] += 1
        }
        return counts.sorted {
            $0.value != $1.value ? $0.value > $1.value : $0.key.displayName < $1.key.displayName
        }.map(\.key)
    }
}
