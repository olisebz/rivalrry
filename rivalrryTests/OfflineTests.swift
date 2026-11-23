import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Phase 3 step 6: offline mode (plan.md §6.1 "Offline"). Changes are kept and sent when the
/// connection is back; answers show as done right away.
struct OfflineTests {

    private struct World {
        let context: ModelContext
        let backend: InMemoryBackend
        let me: Player
        let max: Player
        let localFriend: Player
    }

    private func world(matches: [MatchRecord] = [],
                       autoResponses: [String: (MatchResponse.Kind, String?)] = [:]) throws -> World {
        let container = try ModelContainer(for: Schema(AppSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let me = Player(name: "Alex Morgan", isMe: true, cloudUserID: "me", username: "alex")
        let max = Player(name: "Max Keller", cloudUserID: "max", username: "max_keller")
        let localFriend = Player(name: "Tom")
        for player in [me, max, localFriend] { context.insert(player) }
        let backend = InMemoryBackend(userID: "me",
                                      profiles: [OnlineProfile(userID: "me", username: "alex", name: "Alex Morgan",
                                                               colorHex: "6E6E73")],
                                      matches: matches, autoResponses: autoResponses)
        return World(context: context, backend: backend, me: me, max: max, localFriend: localFriend)
    }

    private func sync(_ world: World) async throws {
        try await MatchSync.sync(me: world.me, context: world.context, backend: world.backend)
    }

    private func waiting(_ world: World) throws -> [PendingAction] {
        try Outbox.waiting(in: world.context)
    }

    @discardableResult
    private func logBadminton(_ world: World) -> Match {
        var draft = MatchDraft(sport: Sport(.badminton))
        draft.bestOf = 3
        draft.sets = [SetEntry(scoreA: 21, scoreB: 17), SetEntry(scoreA: 21, scoreB: 19)]
        return draft.insertMatch(me: world.me, friend: world.max, into: world.context)
    }

    private func maxRecord() -> MatchRecord {
        MatchRecord(id: UUID(), creatorUserID: "max", version: 1, sportType: .badminton, mode: .oneVsOne,
                    date: Date(), bestOf: 3,
                    participants: [.init(userID: "max", side: .a), .init(userID: "me", side: .b)],
                    sets: [.init(index: 0, scoreA: 21, scoreB: 15), .init(index: 1, scoreA: 21, scoreB: 18)],
                    createdAt: Date(), updatedAt: Date())
    }

    /// Downloads Max's match, then goes offline.
    private func theirMatchOffline() async throws -> (World, Match) {
        let world = try world(matches: [maxRecord()])
        try await sync(world)
        world.backend.isOffline = true
        return (world, try #require(try world.context.fetch(FetchDescriptor<Match>()).first))
    }

    // MARK: - Matches

    @Test func newMatchWaitsAndGoesUpLater() async throws {
        let world = try world(autoResponses: ["max": (.confirm, nil)])
        world.backend.isOffline = true
        let match = logBadminton(world)

        await #expect(throws: OnlineError.offline) { try await sync(world) }
        #expect(match.needsUpload)
        #expect(match.isWaitingForUpload)
        #expect(match.status == .pending)

        world.backend.isOffline = false
        try await sync(world)
        #expect(!match.needsUpload)
        #expect(world.backend.matches[match.id] != nil)
        #expect(match.status == .confirmed)
    }

    @Test func localMatchesDontWait() throws {
        let world = try world()
        var draft = MatchDraft(sport: Sport(.badminton))
        draft.bestOf = 3
        draft.sets = [SetEntry(scoreA: 21, scoreB: 17), SetEntry(scoreA: 21, scoreB: 19)]
        let match = draft.insertMatch(me: world.me, friend: world.localFriend, into: world.context)
        #expect(!match.isWaitingForUpload)
    }

    // MARK: - Answers

    @Test func confirmOfflineShowsRightAwayAndIsSentLater() async throws {
        let (world, match) = try await theirMatchOffline()

        try await MatchSync.confirm(match, me: world.me, backend: world.backend)
        #expect(try waiting(world).count == 1)
        #expect(match.status == .confirmed)
        #expect(MatchRequests(matches: [match], me: world.me).toConfirm.isEmpty)

        world.backend.isOffline = false
        try await sync(world)
        #expect(try waiting(world).isEmpty)
        #expect(world.backend.responses.map(\.kind) == [.confirm])
        #expect(match.status == .confirmed)
    }

    @Test func rejectOffline() async throws {
        let (world, match) = try await theirMatchOffline()
        try await MatchSync.reject(match, reason: "Wrong score", me: world.me, backend: world.backend)
        #expect(match.status == .rejected)
        #expect(match.rejectionReason == "Wrong score")

        world.backend.isOffline = false
        try await sync(world)
        #expect(world.backend.responses.first?.reason == "Wrong score")
        #expect(match.status == .rejected)
    }

    @Test func confirmInTeamMatchWaitsForTheOthers() async throws {
        var record = maxRecord()
        record.mode = .team
        record.participants += [.init(userID: "tom", side: .a), .init(userID: "lena", side: .b)]
        let world = try world(matches: [record])
        world.context.insert(Player(name: "Tom Berger", cloudUserID: "tom"))
        world.context.insert(Player(name: "Lena Fischer", cloudUserID: "lena"))
        try await sync(world)
        let match = try #require(try world.context.fetch(FetchDescriptor<Match>()).first)
        world.backend.isOffline = true

        try await MatchSync.confirm(match, me: world.me, backend: world.backend)
        // Lena still has to confirm.
        #expect(match.status == .pending)
        #expect(match.confirmedUserIDs == ["me"])
        #expect(!match.needsConfirmation(by: world.me))
    }

    @Test func deletionAnswersOffline() async throws {
        let world = try world(autoResponses: ["max": (.confirm, nil)])
        let match = logBadminton(world)
        try await sync(world)
        world.backend.receive(MatchResponse(matchID: match.id, matchVersion: 1, userID: "max", kind: .requestDelete))
        try await sync(world)
        world.backend.isOffline = true

        try await MatchSync.answerDeletion(match, approve: false, me: world.me, backend: world.backend)
        #expect(match.deletionRequest == nil)
        #expect(try waiting(world).count == 1)

        world.backend.isOffline = false
        try await sync(world)
        #expect(match.deletionRequest == nil)
        #expect(world.backend.matches[match.id] != nil)
    }

    @Test func requestDeletionOffline() async throws {
        let world = try world(autoResponses: ["max": (.confirm, nil)])
        let match = logBadminton(world)
        try await sync(world)
        world.backend.isOffline = true

        try await MatchSync.requestDeletion(match, me: world.me, backend: world.backend)
        #expect(match.deletionText(me: world.me) == "Waiting for Max to approve deletion")

        world.backend.isOffline = false
        // Max (test user who confirms) approves as soon as the request arrives.
        try await sync(world)
        try await sync(world)
        #expect(try world.context.fetch(FetchDescriptor<Match>()).isEmpty)
    }

    @Test func deleteOwnMatchOffline() async throws {
        let world = try world()
        let match = logBadminton(world)
        try await sync(world)
        let id = match.id
        world.backend.isOffline = true

        try await MatchSync.deleteOnline(matchID: id, backend: world.backend, context: world.context)
        world.context.delete(match)
        #expect(try waiting(world).count == 1)

        world.backend.isOffline = false
        try await sync(world)
        #expect(world.backend.matches[id] == nil)
    }

    // MARK: - Outbox

    @Test func orderStaysTheSame() async throws {
        let (world, match) = try await theirMatchOffline()
        try await Outbox.send(.response(MatchResponse(matchID: match.id, matchVersion: 1, userID: "me", kind: .reject,
                                                      reason: "First")),
                              backend: world.backend, context: world.context)
        world.backend.isOffline = false
        // Online again, but older actions wait: this one is queued behind them.
        try await Outbox.send(.response(MatchResponse(matchID: match.id, matchVersion: 1, userID: "me", kind: .confirm)),
                              backend: world.backend, context: world.context)
        #expect(try waiting(world).count == 2)

        try await Outbox.flush(backend: world.backend, context: world.context)
        #expect(try waiting(world).isEmpty)
        // The later answer wins, as it was given last.
        #expect(world.backend.responses.map(\.kind) == [.confirm])
    }

    @Test func refusedActionIsDropped() async throws {
        let (world, match) = try await theirMatchOffline()
        // Not yours to send: the server refuses it, the rest still goes out.
        try await Outbox.send(.response(MatchResponse(matchID: match.id, matchVersion: 1, userID: "max", kind: .confirm)),
                              backend: world.backend, context: world.context)
        try await Outbox.send(.response(MatchResponse(matchID: match.id, matchVersion: 1, userID: "me", kind: .confirm)),
                              backend: world.backend, context: world.context)
        world.backend.isOffline = false
        try await Outbox.flush(backend: world.backend, context: world.context)
        #expect(try waiting(world).isEmpty)
        #expect(world.backend.responses.map(\.userID) == ["me"])
    }

    @Test func stillOfflineKeepsTheQueue() async throws {
        let (world, match) = try await theirMatchOffline()
        try await MatchSync.confirm(match, me: world.me, backend: world.backend)
        await #expect(throws: OnlineError.offline) {
            try await Outbox.flush(backend: world.backend, context: world.context)
        }
        #expect(try waiting(world).count == 1)
    }

    @Test func onlyNewestProfileIsKept() async throws {
        let world = try world()
        world.backend.isOffline = true
        world.me.name = "Alex M."
        try await ProfileSync.push(world.me, backend: world.backend, context: world.context)
        world.me.name = "Alexander Morgan"
        try await ProfileSync.push(world.me, backend: world.backend, context: world.context)
        #expect(try waiting(world).count == 1)

        world.backend.isOffline = false
        try await Outbox.flush(backend: world.backend, context: world.context)
        #expect(world.backend.profiles["me"]?.name == "Alexander Morgan")
    }

    @Test func actionSurvivesEncoding() {
        let link = LinkRecord(userID: "me", friendUserID: "max", localMatchCount: 3, importerUserID: "me",
                              linkedAt: Date(timeIntervalSince1970: 1_000))
        #expect(PendingAction(.link(link)).action == .link(link))
        let id = UUID()
        #expect(PendingAction(.deleteMatch(id)).action == .deleteMatch(id))
    }

    // MARK: - Needs a connection

    @Test func linkingNeedsAConnection() async throws {
        let world = try world()
        let onlineTom = Player(name: "Tom Berger", cloudUserID: "tom", username: "tom_berger")
        world.context.insert(onlineTom)
        world.backend.isOffline = true

        await #expect(throws: OnlineError.offline) {
            try await AccountLinking.link(world.localFriend, to: onlineTom, me: world.me,
                                          context: world.context, backend: world.backend)
        }
        // Nothing changed.
        #expect(world.localFriend.cloudUserID == nil)
        #expect(try world.context.fetch(FetchDescriptor<Player>()).count == 4)
    }

    @Test func usernameNeedsAConnection() async throws {
        let world = try world()
        world.backend.isOffline = true
        let me = Player(name: "Alex", isMe: true)
        await #expect(throws: OnlineError.offline) {
            try await ProfileSync.claimUsername("alex2", for: me, backend: world.backend)
        }
        #expect(me.username == nil)
    }

    @Test func resetDeletesTheQueue() async throws {
        let (world, match) = try await theirMatchOffline()
        try await MatchSync.confirm(match, me: world.me, backend: world.backend)
        try Rivalry.resetAllData(in: world.context)
        #expect(try waiting(world).isEmpty)
    }
}
