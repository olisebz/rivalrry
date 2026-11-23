import Foundation
import SwiftData

/// Groups shared with their online members (Phase 4 step 1, plan.md S8). Any member can rename the group
/// and add or remove members. Local friends can be members too, but only on your phone.
///
/// Changes show here right away and go through the `Outbox`, so they're sent later when offline.
/// Before you have chosen a username, groups stay on your phone; the next sync uploads them.
enum GroupSync {

    /// "New Group": you plus `friends`. Returns `nil` if the name is empty.
    @discardableResult
    static func create(name: String, symbolName: String, friends: [Player], me: Player,
                       context: ModelContext, backend: any OnlineBackend) async throws -> PlayerGroup? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let group = PlayerGroup(name: name, symbolName: symbolName,
                                members: [me] + friends.filter { !$0.isMe })
        if let myUserID = me.cloudUserID {
            let record = record(of: group, creator: myUserID)
            try await Outbox.send(.saveGroup(record), backend: backend, context: context)
            group.isOnline = true
            group.memberUserIDs = record.memberUserIDs
        }
        context.insert(group)
        return group
    }

    /// New name and symbol.
    static func rename(_ group: PlayerGroup, name: String, symbolName: String, me: Player,
                       context: ModelContext, backend: any OnlineBackend) async throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if group.isOnline, let myUserID = me.cloudUserID {
            var record = record(of: group, creator: myUserID)
            record.name = name
            record.symbolName = symbolName
            try await Outbox.send(.saveGroup(record), backend: backend, context: context)
        }
        group.name = name
        group.symbolName = symbolName
    }

    static func add(_ players: [Player], to group: PlayerGroup,
                    context: ModelContext, backend: any OnlineBackend) async throws {
        let new = players.filter { player in !group.members.contains { $0.id == player.id } }
        let newUserIDs = new.compactMap(\.cloudUserID).filter { !group.memberUserIDs.contains($0) }
        if group.isOnline, !newUserIDs.isEmpty {
            try await Outbox.send(.addGroupMembers(groupID: group.id, userIDs: newUserIDs),
                                  backend: backend, context: context)
            group.memberUserIDs += newUserIDs
        }
        group.members += new
    }

    /// Removes a member. For yourself use `leave`.
    static func remove(_ player: Player, from group: PlayerGroup,
                       context: ModelContext, backend: any OnlineBackend) async throws {
        guard !player.isMe else { return }
        if group.isOnline, let userID = player.cloudUserID, group.memberUserIDs.contains(userID) {
            try await Outbox.send(.removeGroupMember(groupID: group.id, userID: userID),
                                  backend: backend, context: context)
            group.memberUserIDs.removeAll { $0 == userID }
        }
        group.members.removeAll { $0.id == player.id }
    }

    /// "Leave Group": removes you for everyone and deletes the group here.
    static func leave(_ group: PlayerGroup, me: Player,
                      context: ModelContext, backend: any OnlineBackend) async throws {
        if group.isOnline, let myUserID = me.cloudUserID {
            try await Outbox.send(.removeGroupMember(groupID: group.id, userID: myUserID),
                                  backend: backend, context: context)
        }
        context.delete(group)
    }

    // MARK: - Sync

    static func sync(me: Player, context: ModelContext, backend: any OnlineBackend) async throws {
        guard let myUserID = me.cloudUserID else { return }
        try await Outbox.flush(backend: backend, context: context)
        let local = try context.fetch(FetchDescriptor<PlayerGroup>())

        for group in local {
            if !group.isOnline {
                // 1. Made before you had a username: goes online now.
                let record = record(of: group, creator: myUserID)
                try await backend.saveGroup(record)
                group.isOnline = true
                group.memberUserIDs = record.memberUserIDs
            } else {
                // 2. Local friends you linked since the last sync join online.
                let newUserIDs = onlineUserIDs(of: group).filter { !group.memberUserIDs.contains($0) }
                guard !newUserIDs.isEmpty else { continue }
                do {
                    try await backend.addGroupMembers(groupID: group.id, userIDs: newUserIDs)
                    group.memberUserIDs += newUserIDs
                } catch OnlineError.notAllowed {
                    // You were removed meanwhile; step 4 deletes the group.
                }
            }
        }

        // 3. Download the groups you are in.
        let records = try await backend.fetchGroups()
        var playersByUserID: [String: Player] = [:]
        for player in try context.fetch(FetchDescriptor<Player>()) {
            guard let userID = player.cloudUserID else { continue }
            if playersByUserID[userID] == nil || player.isMe { playersByUserID[userID] = player }
        }
        let localByID = Dictionary(local.map { ($0.id, $0) }) { first, _ in first }
        for record in records {
            let group: PlayerGroup
            if let existing = localByID[record.id] {
                group = existing
            } else {
                group = PlayerGroup(name: record.name, createdAt: record.createdAt)
                group.id = record.id
                group.isOnline = true
                context.insert(group)
            }
            group.name = record.name
            group.symbolName = record.symbolName
            group.memberUserIDs = record.memberUserIDs
            let localFriends = group.members.filter { $0.cloudUserID == nil }
            group.members = record.memberUserIDs.compactMap { playersByUserID[$0] } + localFriends
        }

        // 4. Groups you left or were removed from disappear here.
        let onlineIDs = Set(records.map(\.id))
        for group in local where group.isOnline && !onlineIDs.contains(group.id) {
            context.delete(group)
        }
    }

    // MARK: - Converting

    /// The online members of a group: those with an online account.
    static func onlineUserIDs(of group: PlayerGroup) -> [String] {
        group.members.compactMap(\.cloudUserID)
    }

    static func record(of group: PlayerGroup, creator: String) -> GroupRecord {
        GroupRecord(id: group.id, name: group.name, symbolName: group.symbolName,
                    memberUserIDs: onlineUserIDs(of: group), createdByUserID: creator, createdAt: group.createdAt)
    }
}
