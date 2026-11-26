import Foundation

/// The "New Group" form (plan.md §4 S1/S8): name, symbol (decision 4), members.
struct GroupForm: Equatable {
    var name = ""
    var symbolName = CustomSport.symbols[0]
    /// Chosen friends; you are always a member.
    var memberIDs: Set<UUID> = []

    static let nameLimit = 30

    init() {}

    /// "Edit Group": the current name, symbol and members (without you).
    init(group: PlayerGroup) {
        name = group.name
        symbolName = group.symbolName
        memberIDs = Set(group.members.filter { !$0.isMe }.map(\.id))
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Why the form can't be saved, `nil` if it can.
    var issue: String? {
        if trimmedName.isEmpty { return "Enter a name." }
        if trimmedName.count > Self.nameLimit { return "Use at most \(Self.nameLimit) characters." }
        if memberIDs.isEmpty { return "Choose at least one friend." }
        return nil
    }

    /// Friends you can pick: not archived, by name. When editing, archived members stay in the list.
    static func candidates(in players: [Player], group: PlayerGroup? = nil) -> [Player] {
        let memberIDs = Set(group?.members.map(\.id) ?? [])
        return players.filter { !$0.isMe && (!$0.isArchived || memberIDs.contains($0.id)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func members(from players: [Player], group: PlayerGroup? = nil) -> [Player] {
        Self.candidates(in: players, group: group).filter { memberIDs.contains($0.id) }
    }

    /// Who "Save" adds to and removes from `group`.
    func memberChanges(for group: PlayerGroup, players: [Player]) -> (added: [Player], removed: [Player]) {
        let current = Set(group.members.map(\.id))
        let added = members(from: players, group: group).filter { !current.contains($0.id) }
        let removed = group.members.filter { !$0.isMe && !memberIDs.contains($0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return (added, removed)
    }
}

extension PlayerGroup {
    /// Everyone in the group: local players plus online members who aren't your friends.
    var memberCount: Int {
        let known = Set(members.compactMap(\.cloudUserID))
        return members.count + memberUserIDs.filter { !known.contains($0) }.count
    }

    /// "4 members"
    var memberCountText: String {
        memberCount == 1 ? "1 member" : "\(memberCount) members"
    }

    /// Online members who aren't your friends: shown as "and 2 others" (S8).
    var otherMemberCount: Int { memberCount - members.count }

    /// "and 1 other", "and 2 others"; `nil` if every member is known.
    var otherMembersText: String? {
        switch otherMemberCount {
        case ...0: nil
        case 1: "and 1 other"
        default: "and \(otherMemberCount) others"
        }
    }

    /// Who you can play in S8 "Add Match": the other members who aren't archived. Team partners and
    /// race participants also come only from them.
    var opponents: [Player] {
        members.filter { !$0.isMe && !$0.isArchived }
    }

    /// S8 member rows: you first, then by name.
    var sortedMembers: [Player] {
        members.sorted { lhs, rhs in
            if lhs.isMe != rhs.isMe { return lhs.isMe }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// The group's matches (agreed with the user): every match where all participants are members,
    /// wherever it was logged. Newest first.
    func matches(in matches: [Match]) -> [Match] {
        let memberIDs = Set(members.map(\.id))
        return matches
            .filter { match in
                match.participants.count >= 2
                    && match.participants.allSatisfy { $0.player.map { memberIDs.contains($0.id) } ?? false }
            }
            .sorted { $0.date > $1.date }
    }

    /// Groups on S1, by name.
    static func sorted(_ groups: [PlayerGroup]) -> [PlayerGroup] {
        groups.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
