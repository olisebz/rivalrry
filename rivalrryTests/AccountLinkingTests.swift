import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Phase 3 step 5: "Link to Account" and the import of old local matches (plan.md §6.3).
struct AccountLinkingTests {

    private struct World {
        let context: ModelContext
        let backend: InMemoryBackend
        let me: Player
        /// Max as a local friend (before the app), with old matches.
        let localMax: Player
        /// Max as online friend (after the friend request).
        let onlineMax: Player
    }

    private func world(oldMatches: Int = 3, links: [LinkRecord] = [],
                       autoResponses: [String: (MatchResponse.Kind, String?)] = [:],
                       matches: [MatchRecord] = []) throws -> World {
        let container = try ModelContainer(for: Schema(AppSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let me = Player(name: "Alex Morgan", isMe: true, cloudUserID: "me", username: "alex")
        let localMax = Player(name: "Max")
        let onlineMax = Player(name: "Max Keller", colorHex: "4F6BED", cloudUserID: "max", username: "max_keller")
        for player in [me, localMax, onlineMax] { context.insert(player) }
        for _ in 0..<oldMatches { logBadminton(me: me, against: localMax, context: context) }
        let backend = InMemoryBackend(userID: "me", matches: matches, autoResponses: autoResponses, links: links)
        return World(context: context, backend: backend, me: me, localMax: localMax, onlineMax: onlineMax)
    }

    @discardableResult
    private func logBadminton(me: Player, against friend: Player, context: ModelContext) -> Match {
        var draft = MatchDraft(sport: Sport(.badminton))
        draft.bestOf = 3
        draft.sets = [SetEntry(scoreA: 21, scoreB: 17), SetEntry(scoreA: 21, scoreB: 19)]
        return draft.insertMatch(me: me, friend: friend, into: context)
    }

    private func matches(_ world: World) throws -> [Match] {
        try world.context.fetch(FetchDescriptor<Match>())
    }

    private func link(_ world: World) async throws -> AccountLinking.Outcome {
        try await AccountLinking.link(world.localMax, to: world.onlineMax, me: world.me,
                                      context: world.context, backend: world.backend)
    }

    private func sync(_ world: World) async throws {
        try await MatchSync.sync(me: world.me, context: world.context, backend: world.backend)
    }

    // MARK: - Linking

    @Test func linkMergesBothPlayers() async throws {
        let world = try world(oldMatches: 0)
        #expect(AccountLinking.candidates(in: [world.me, world.localMax, world.onlineMax]) == [world.onlineMax])
        #expect(try await link(world) == .nothingToImport)

        let players = try world.context.fetch(FetchDescriptor<Player>())
        #expect(players.count == 2)
        #expect(world.localMax.cloudUserID == "max")
        #expect(world.localMax.username == "max_keller")
        #expect(world.localMax.name == "Max Keller")
    }

    @Test func firstToLinkImportsRightAway() async throws {
        let world = try world()
        #expect(try await link(world) == .importing(count: 3))

        let old = try matches(world)
        #expect(old.allSatisfy { $0.status == .pending && $0.isImported && $0.needsUpload })
        #expect(old.allSatisfy { !$0.countsTowardRecord })
        #expect(world.backend.links.first?.importerUserID == "me")
        #expect(world.backend.links.first?.localMatchCount == 3)

        try await sync(world)
        #expect(world.backend.matches.count == 3)
        #expect(world.backend.matches.values.allSatisfy { $0.isImported && $0.opponentUserIDs == ["max"] })
    }

    @Test func matchesOfTheOnlineEntryMoveOver() async throws {
        let world = try world(oldMatches: 1)
        // A new online match with Max from before linking.
        let online = logBadminton(me: world.me, against: world.onlineMax, context: world.context)
        #expect(online.status == .pending)
        _ = try await link(world)
        #expect(online.includes(world.localMax))
        #expect(Rivalry.matches(of: world.me, with: world.localMax, in: try matches(world)).count == 2)
    }

    // MARK: - Confirm / reject the import

    @Test func confirmedImportCounts() async throws {
        let world = try world(autoResponses: ["max": (.confirm, nil)])
        _ = try await link(world)
        try await sync(world)
        let old = try matches(world)
        #expect(old.allSatisfy { $0.status == .confirmed })
        #expect(Rivalry.record(of: world.me, against: world.localMax, in: old).wins == 3)
    }

    @Test func rejectedImportStaysLocalAndCountsForYou() async throws {
        let world = try world(oldMatches: 1, autoResponses: ["max": (.reject, "Never played that")])
        _ = try await link(world)
        try await sync(world)

        let match = try #require(try matches(world).first)
        #expect(match.status == .local)
        #expect(match.localOnly == .rejectedImport)
        #expect(match.countsTowardRecord)
        #expect(match.localNote == "Local only · Rejected by Max: Never played that")
        #expect(world.backend.matches.isEmpty)
        // It isn't imported again with the next sync.
        try await sync(world)
        #expect(world.backend.matches.isEmpty)
        #expect(match.status == .local)
    }

    @Test func friendSeesOneBulkRequest() async throws {
        func imported() -> MatchRecord {
            MatchRecord(id: UUID(), creatorUserID: "max", version: 1, sportType: .badminton, mode: .oneVsOne,
                        date: Date(), bestOf: 3, isImported: true,
                        participants: [.init(userID: "max", side: .a), .init(userID: "me", side: .b)],
                        sets: [.init(index: 0, scoreA: 21, scoreB: 15), .init(index: 1, scoreA: 21, scoreB: 18)],
                        createdAt: Date(), updatedAt: Date())
        }
        let normal = MatchRecord(id: UUID(), creatorUserID: "max", version: 1, sportType: .badminton,
                                 mode: .oneVsOne, date: Date(), bestOf: 3,
                                 participants: [.init(userID: "max", side: .a), .init(userID: "me", side: .b)],
                                 sets: [.init(index: 0, scoreA: 21, scoreB: 15), .init(index: 1, scoreA: 21, scoreB: 18)],
                                 createdAt: Date(), updatedAt: Date())
        let world = try world(oldMatches: 0, matches: [imported(), imported(), normal])
        try await sync(world)

        let requests = MatchRequests(matches: try matches(world), me: world.me)
        #expect(requests.imported.count == 1)
        #expect(requests.imported.first?.title == "Max imported 2 matches with you")
        #expect(requests.toConfirm.count == 1)
        #expect(requests.actionCount == 2)

        // "Confirm All"
        for match in try #require(requests.imported.first).matches {
            try await MatchSync.confirm(match, me: world.me, backend: world.backend)
        }
        try await sync(world)
        #expect(MatchRequests(matches: try matches(world), me: world.me).imported.isEmpty)
    }

    // MARK: - Who imports

    @Test func friendAlreadyImported() async throws {
        let world = try world(links: [LinkRecord(userID: "max", friendUserID: "me", localMatchCount: 12,
                                                 importerUserID: "max")])
        #expect(try await link(world) == .alreadyImported(by: "Max", count: 12))

        let old = try matches(world)
        #expect(old.allSatisfy { $0.localOnly == .duplicate && $0.status == .local })
        #expect(old.allSatisfy { !$0.countsTowardRecord })
        #expect(old.first?.localNote == "Local only · Max imported these matches")
        #expect(Rivalry.record(of: world.me, against: world.localMax, in: old).matches == 0)
        try await sync(world)
        #expect(world.backend.matches.isEmpty)
    }

    @Test func bothHaveMatchesAsksWhoImports() async throws {
        let world = try world(links: [LinkRecord(userID: "max", friendUserID: "me", localMatchCount: 5)])
        #expect(try await link(world) == .chooseImporter(friendCount: 5))
        // Nothing happens until you choose.
        #expect(try matches(world).allSatisfy { $0.status == .local && $0.localOnly == nil })

        try await AccountLinking.chooseImporter(youImport: false, friend: world.localMax, me: world.me,
                                                context: world.context, backend: world.backend)
        #expect(try matches(world).allSatisfy { $0.localOnly == .duplicate })
        #expect(world.backend.links.first { $0.userID == "me" }?.importerUserID == "max")
    }

    @Test func youChooseToImport() async throws {
        let world = try world(links: [LinkRecord(userID: "max", friendUserID: "me", localMatchCount: 5)])
        _ = try await link(world)
        try await AccountLinking.chooseImporter(youImport: true, friend: world.localMax, me: world.me,
                                                context: world.context, backend: world.backend)
        #expect(try matches(world).allSatisfy { $0.status == .pending && $0.isImported })
    }

    @Test func friendsChoiceArrivesWithSync() async throws {
        let world = try world(links: [LinkRecord(userID: "max", friendUserID: "me", localMatchCount: 5)])
        _ = try await link(world)
        // Max answers "Who imports?" on his phone with "Max imports".
        world.backend.receive(LinkRecord(userID: "max", friendUserID: "me", localMatchCount: 5, importerUserID: "max"))
        try await sync(world)
        #expect(world.localMax.importsMatches == false)
        #expect(try matches(world).allSatisfy { $0.localOnly == .duplicate })
    }

    @Test func friendChoosesYou() async throws {
        let world = try world(links: [LinkRecord(userID: "max", friendUserID: "me", localMatchCount: 5)])
        _ = try await link(world)
        world.backend.receive(LinkRecord(userID: "max", friendUserID: "me", localMatchCount: 5, importerUserID: "me"))
        try await sync(world)
        #expect(world.localMax.importsMatches == true)
        #expect(world.backend.matches.count == 3)
    }

    // MARK: - Several local players

    @Test func teamMatchWaitsForEveryone() async throws {
        let world = try world(oldMatches: 0)
        let tom = Player(name: "Tom")
        let lukas = Player(name: "Lukas")
        let onlineTom = Player(name: "Tom Berger", cloudUserID: "tom", username: "tom_berger")
        let onlineLukas = Player(name: "Lukas Huber", cloudUserID: "lukas", username: "lukas_huber")
        for player in [tom, lukas, onlineTom, onlineLukas] { world.context.insert(player) }
        var draft = MatchDraft(sport: Sport(.padel))
        draft.mode = .team
        draft.partners = [tom]
        draft.opponents = [lukas]
        draft.bestOf = 3
        draft.sets = [SetEntry(scoreA: 6, scoreB: 3), SetEntry(scoreA: 6, scoreB: 4)]
        let match = draft.insertMatch(me: world.me, friend: world.localMax, into: world.context)

        #expect(try await link(world) == .importing(count: 1))
        #expect(match.status == .local)
        #expect(match.localNote == "Waiting for 2 more players to join")

        _ = try await AccountLinking.link(tom, to: onlineTom, me: world.me, context: world.context, backend: world.backend)
        #expect(match.localNote == "Waiting for 1 more player to join")
        _ = try await AccountLinking.link(lukas, to: onlineLukas, me: world.me, context: world.context,
                                          backend: world.backend)
        #expect(match.status == .pending)
        #expect(match.isImported)
        #expect(match.localNote == nil)
    }
}
