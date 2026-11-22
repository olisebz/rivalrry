import Foundation

/// S5 – Quick Add: log a match from S1 without opening the friend first (plan.md §4 S5).
enum QuickAdd {

    /// The sport of your most recent counting match, if it can still be entered.
    static func preselectedSport(me: Player, matches: [Match], available: [SportType]) -> SportType? {
        matches
            .filter { $0.countsTowardRecord && $0.includes(me) && available.contains($0.sportType) }
            .max { $0.date < $1.date }?
            .sportType
    }

    /// Active friends, most recent opponents first; friends without matches after them, newest first.
    static func opponents(me: Player, friends: [Player], matches: [Match]) -> [Player] {
        let active = friends.filter { !$0.isMe && !$0.isArchived }
        let lastPlayed = Dictionary(uniqueKeysWithValues: active.map {
            ($0.id, Rivalry.lastMatch(of: me, with: $0, in: matches)?.date)
        })
        return active.sorted { lhs, rhs in
            switch (lastPlayed[lhs.id] ?? nil, lastPlayed[rhs.id] ?? nil) {
            case let (l?, r?) where l != r: l > r
            case (.some, nil): true
            case (nil, .some): false
            default: lhs.createdAt > rhs.createdAt
            }
        }
    }
}
