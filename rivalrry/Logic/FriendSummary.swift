import Foundation

/// Everything a friend card on S1 shows.
struct FriendSummary: Identifiable {
    let friend: Player
    let record: Record
    let lastMatch: Match?
    /// Current streak from 3 on (plan.md §4 S1).
    var streak: Streak? = nil
    /// Matches with this friend wait for confirmation (Phase 3): small clock on the card.
    var hasPending = false

    var id: UUID { friend.id }
}

/// Sort options of the S1 sort menu.
enum RivalsSort: String, CaseIterable, Identifiable {
    case recentlyPlayed, name, mostMatches

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentlyPlayed: "Recently played"
        case .name: "Name"
        case .mostMatches: "Most matches"
        }
    }
}

extension Rivalry {

    /// One summary per friend, sorted for S1.
    static func summaries(of me: Player?, friends: [Player], matches: [Match],
                          sortedBy sort: RivalsSort) -> [FriendSummary] {
        let summaries = friends.map { friend in
            FriendSummary(
                friend: friend,
                record: me.map { record(of: $0, against: friend, in: matches) } ?? Record(),
                lastMatch: me.flatMap { lastMatch(of: $0, with: friend, in: matches) },
                streak: me.flatMap { cardStreak(of: $0, against: friend, in: matches) },
                hasPending: me.map { me in
                    matches.contains { $0.status == .pending && $0.includes(me) && $0.includes(friend) }
                } ?? false
            )
        }
        return summaries.sorted { lhs, rhs in
            switch sort {
            case .recentlyPlayed:
                // Friends without matches go last, newest first.
                switch (lhs.lastMatch?.date, rhs.lastMatch?.date) {
                case let (l?, r?) where l != r: return l > r
                case (.some, nil): return true
                case (nil, .some): return false
                default: return lhs.friend.createdAt > rhs.friend.createdAt
                }
            case .name:
                return lhs.friend.name.localizedStandardCompare(rhs.friend.name) == .orderedAscending
            case .mostMatches:
                if lhs.record.matches != rhs.record.matches { return lhs.record.matches > rhs.record.matches }
                return lhs.friend.name.localizedStandardCompare(rhs.friend.name) == .orderedAscending
            }
        }
    }
}

extension Player {
    /// 1–2 letters for the avatar: "Max Keller" → "MK", "Max" → "M" (design.md §2.5).
    static func initials(for name: String) -> String {
        let words = name.split(separator: " ").prefix(2)
        return words.compactMap(\.first).map { String($0).uppercased() }.joined()
    }

    var initials: String { Self.initials(for: name) }

    /// First name, as shown on cards ("Max Keller" → "Max").
    var shortName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

enum RelativeDay {
    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .full
        return formatter
    }()

    /// "today", "yesterday", "2 days ago", "1 week ago", "3 weeks ago" …
    static func text(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let start = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        switch days {
        case ...0: return "today"
        case 1: return "yesterday"
        default: return formatter.localizedString(for: start, relativeTo: today)
        }
    }
}
