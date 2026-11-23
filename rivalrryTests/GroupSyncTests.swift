import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Phase 4 step 1: groups shared online with their members (plan.md S8). Local friends can be members,
/// but only online members get the group.
struct GroupSyncTests {

    private struct World {
        let context: ModelContext
        let backend: InMemoryBackend
        let me: Player
        let max: Player
        let jonas: Player
        let localTom: Player
    }

    private func world(username: Bool = true, groups: [GroupRecord] = []) throws -> World {
        let container = try ModelContainer(for: Schema(AppSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let me = Player(name: "Alex Morgan", isMe: true,
                        cloudUserID: username ? "me" : nil, username: username ? "alex" : nil)
        let max = Player(name: "Max Keller", cloudUserID: "max", username: "max_keller")
        let jonas = Player(name: "Jonas Weber", cloudUserID: "jonas", username: "jonas_weber")
        let localTom = Player(name: "Tom")
        for player in [me, max, jonas, localTom] { context.insert(player) }
        return World(context: context, backend: InMemoryBackend(userID: "me", groups: groups),
                     me: me, max: max, jonas: jonas, localTom: localTom)
    }

    private func sync(_ world: World) async throws {
        try await GroupSync.sync(me: world.me, context: world.context, backend: world.backend)
    }

    private func localGroups(_ world: World) throws -> [PlayerGroup] {
        try world.context.fetch(FetchDescriptor<PlayerGroup>())
    }

    @discardableResult
    private func createPadel(_ world: World) async throws -> PlayerGroup {
        try #require(try await GroupSync.create(
            name: "  Padel every Thursday ", symbolName: "figure.tennis", friends: [world.max, world.localTom],
            me: world.me, context: world.context, backend: world.backend))
    }

    private func names(_ group: PlayerGroup) -> Set<String> {
        Set(group.members.map(\.name))
    }

    // MARK: - Creating

    @Test func newGroupGoesOnlineWithOnlyOnlineMembers() async throws {
        let world = try world()
        let group = try await createPadel(world)

        #expect(group.name == "Padel every Thursday")
        #expect(group.isOnline)
        #expect(names(group) == ["Alex Morgan", "Max Keller", "Tom"])
        let online = try #require(world.backend.groups[group.id])
        #expect(online.name == "Padel every Thursday")
        #expect(online.symbolName == "figure.tennis")
        #expect(Set(online.memberUserIDs) == ["me", "max"])
        #expect(online.createdByUserID == "me")
    }

    @Test func emptyNameCreatesNothing() async throws {
        let world = try world()
        let group = try await GroupSync.create(name: "   ", symbolName: "person.3", friends: [world.max],
                                               me: world.me, context: world.context, backend: world.backend)
        #expect(group == nil)
        #expect(try localGroups(world).isEmpty)
        #expect(world.backend.groups.isEmpty)
    }

    @Test func withoutUsernameTheGroupStaysLocalUntilTheNextSync() async throws {
        let world = try world(username: false)
        let group = try await createPadel(world)
        #expect(!group.isOnline)
        #expect(world.backend.groups.isEmpty)

        world.me.cloudUserID = "me"
        world.me.username = "alex"
        try await sync(world)
        #expect(group.isOnline)
        #expect(Set(try #require(world.backend.groups[group.id]).memberUserIDs) == ["me", "max"])
        #expect(names(group) == ["Alex Morgan", "Max Keller", "Tom"])
    }

    // MARK: - Changing

    @Test func renameReachesTheServer() async throws {
        let world = try world()
        let group = try await createPadel(world)
        try await GroupSync.rename(group, name: "Padel Club", symbolName: "trophy", me: world.me,
                                   context: world.context, backend: world.backend)
        #expect(group.name == "Padel Club")
        #expect(world.backend.groups[group.id]?.name == "Padel Club")
        #expect(world.backend.groups[group.id]?.symbolName == "trophy")
    }

    @Test func addAndRemoveMembers() async throws {
        let world = try world()
        let group = try await createPadel(world)

        try await GroupSync.add([world.jonas, world.max], to: group, context: world.context, backend: world.backend)
        #expect(names(group) == ["Alex Morgan", "Max Keller", "Tom", "Jonas Weber"])
        #expect(Set(try #require(world.backend.groups[group.id]).memberUserIDs) == ["me", "max", "jonas"])

        try await GroupSync.remove(world.max, from: group, context: world.context, backend: world.backend)
        try await GroupSync.remove(world.localTom, from: group, context: world.context, backend: world.backend)
        #expect(names(group) == ["Alex Morgan", "Jonas Weber"])
        #expect(Set(try #require(world.backend.groups[group.id]).memberUserIDs) == ["me", "jonas"])
    }

    @Test func leaveRemovesYouForEveryone() async throws {
        let world = try world()
        let group = try await createPadel(world)
        let id = group.id
        try await GroupSync.leave(group, me: world.me, context: world.context, backend: world.backend)

        #expect(try localGroups(world).isEmpty)
        #expect(world.backend.groups[id]?.memberUserIDs == ["max"])
    }

    @Test func theLastMemberLeavingDeletesTheGroupOnline() async throws {
        let world = try world()
        let group = try #require(try await GroupSync.create(
            name: "Solo", symbolName: "person.3", friends: [world.localTom],
            me: world.me, context: world.context, backend: world.backend))
        let id = group.id
        try await GroupSync.leave(group, me: world.me, context: world.context, backend: world.backend)
        #expect(world.backend.groups[id] == nil)
    }

    // MARK: - Sync

    @Test func aGroupAFriendMadeIsDownloaded() async throws {
        let record = GroupRecord(id: UUID(), name: "Office League", symbolName: "trophy",
                                 memberUserIDs: ["max", "me", "jonas", "stranger"], createdByUserID: "max")
        let world = try world(groups: [record])
        try await sync(world)

        let group = try #require(try localGroups(world).first)
        #expect(group.id == record.id)
        #expect(group.name == "Office League")
        #expect(group.isOnline)
        // Members who aren't your friends are only known by their user ID.
        #expect(names(group) == ["Alex Morgan", "Max Keller", "Jonas Weber"])
        #expect(group.memberUserIDs == ["max", "me", "jonas", "stranger"])
    }

    @Test func changesByOthersArriveAndLocalFriendsStay() async throws {
        let world = try world()
        let group = try await createPadel(world)
        var changed = try #require(world.backend.groups[group.id])
        changed.name = "Padel Thursdays"
        changed.memberUserIDs = ["me", "jonas"]
        world.backend.receive(changed)

        try await sync(world)
        #expect(group.name == "Padel Thursdays")
        #expect(names(group) == ["Alex Morgan", "Jonas Weber", "Tom"])
    }

    @Test func removedByOthersTheGroupDisappears() async throws {
        let world = try world()
        let group = try await createPadel(world)
        var changed = try #require(world.backend.groups[group.id])
        changed.memberUserIDs = ["max"]
        world.backend.receive(changed)

        try await sync(world)
        #expect(try localGroups(world).isEmpty)
    }

    @Test func aLinkedLocalFriendJoinsOnline() async throws {
        let world = try world()
        let group = try await createPadel(world)
        world.localTom.cloudUserID = "tom"

        try await sync(world)
        #expect(Set(try #require(world.backend.groups[group.id]).memberUserIDs) == ["me", "max", "tom"])
        #expect(names(group) == ["Alex Morgan", "Max Keller", "Tom"])
    }

    @Test func groupsOnlyContainingOthersAreNotDownloaded() async throws {
        let record = GroupRecord(id: UUID(), name: "Not mine", symbolName: "trophy",
                                 memberUserIDs: ["max", "jonas"], createdByUserID: "max")
        let world = try world(groups: [record])
        try await sync(world)
        #expect(try localGroups(world).isEmpty)
        await #expect(throws: OnlineError.notAllowed) {
            try await world.backend.addGroupMembers(groupID: record.id, userIDs: ["me"])
        }
    }

    // MARK: - Offline

    @Test func offlineChangesAreSentLater() async throws {
        let world = try world()
        world.backend.isOffline = true
        let group = try await createPadel(world)
        try await GroupSync.add([world.jonas], to: group, context: world.context, backend: world.backend)
        try await GroupSync.rename(group, name: "Padel Club", symbolName: "trophy", me: world.me,
                                   context: world.context, backend: world.backend)

        #expect(group.isOnline)
        #expect(names(group) == ["Alex Morgan", "Max Keller", "Tom", "Jonas Weber"])
        #expect(try Outbox.waiting(in: world.context).count == 3)
        await #expect(throws: OnlineError.offline) { try await sync(world) }
        #expect(try localGroups(world).count == 1)

        world.backend.isOffline = false
        try await sync(world)
        #expect(try Outbox.waiting(in: world.context).isEmpty)
        let online = try #require(world.backend.groups[group.id])
        #expect(online.name == "Padel Club")
        #expect(Set(online.memberUserIDs) == ["me", "max", "jonas"])
        #expect(names(group) == ["Alex Morgan", "Max Keller", "Tom", "Jonas Weber"])
    }
}
