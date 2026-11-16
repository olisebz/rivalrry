import Foundation

/// Races (mode `.race`): Go-Kart with placements, Running with 3+ runners (plan.md §2.2, §2.3).
extension Match {

    /// Sort key per participant: lower is better. DNF is always last.
    private func raceKey(_ participant: MatchParticipant) -> Int {
        if participant.dnf { return .max }
        switch scoringType {
        case .time: return participant.timeMs ?? .max
        default: return participant.place ?? .max
        }
    }

    /// Finishing place of a participant: 1 + everyone strictly ahead (same time = same place).
    /// `nil` for DNF.
    func racePlace(of participant: MatchParticipant) -> Int? {
        let key = raceKey(participant)
        guard key != .max else { return nil }
        return 1 + participants.filter { raceKey($0) < key }.count
    }

    func racePlace(of player: Player) -> Int? {
        participants.first { $0.player?.id == player.id }.flatMap { racePlace(of: $0) }
    }

    /// Participants in finishing order, DNF last.
    var raceOrder: [MatchParticipant] {
        participants.sorted { raceKey($0) < raceKey($1) }
    }

    /// Duels of `player` against everyone else in the race (plan.md §2.3):
    /// ahead = win, same place = draw, both DNF = draw.
    func raceDuels(for player: Player) -> [Duel] {
        guard let mine = participants.first(where: { $0.player?.id == player.id }) else { return [] }
        let myKey = raceKey(mine)
        return participants.filter { $0 !== mine }.map { other in
            let theirKey = raceKey(other)
            let outcome: DuelOutcome = myKey < theirKey ? .win : myKey > theirKey ? .loss : .draw
            return Duel(match: self, opponent: other.player, outcome: outcome)
        }
    }

    /// A race needs 2–12 participants (plan.md §2.2).
    var isValidRace: Bool { (2...12).contains(participants.count) }
}

/// Ordinal place: "1st", "2nd", "3rd", "4th", "11th", "21st".
enum Ordinal {
    nonisolated static func text(_ number: Int) -> String {
        let tens = number % 100
        let suffix: String
        if (11...13).contains(tens) {
            suffix = "th"
        } else {
            switch number % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(number)\(suffix)"
    }
}
