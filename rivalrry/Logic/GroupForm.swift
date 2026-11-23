import Foundation

/// The "New Group" form (plan.md §4 S1/S8): name, symbol (decision 4), members.
struct GroupForm: Equatable {
    var name = ""
    var symbolName = CustomSport.symbols[0]
    /// Chosen friends; you are always a member.
    var memberIDs: Set<UUID> = []

    static let nameLimit = 30

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Why the form can't be saved, `nil` if it can.
    var issue: String? {
        if trimmedName.isEmpty { return "Enter a name." }
        if trimmedName.count > Self.nameLimit { return "Use at most \(Self.nameLimit) characters." }
        if memberIDs.isEmpty { return "Choose at least one friend." }
        return nil
    }

    /// Friends you can add: not archived, by name.
    static func candidates(in players: [Player]) -> [Player] {
        players.filter { !$0.isMe && !$0.isArchived }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func members(from players: [Player]) -> [Player] {
        Self.candidates(in: players).filter { memberIDs.contains($0.id) }
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

    /// Groups on S1, by name.
    static func sorted(_ groups: [PlayerGroup]) -> [PlayerGroup] {
        groups.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
