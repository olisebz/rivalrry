import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Phase 3 step 3: match sync, `MatchResponse` and the status `Pending` / `Confirmed` / `Rejected`.
struct MatchSyncTests {

    private struct World {
        let context: ModelContext
        let backend: InMemoryBackend
        let me: Player
        let max: Player
        let tom: Player
        let local: Player
    }

    /// You ("me"), online friends Max and Tom, and Lukas as a local friend without the app.
    private func world(autoResponses: [String: (MatchResponse.Kind, String?)] = [:],
                       matches: [MatchRecord] = []) throws -> World {
        let container = try ModelContainer(for: Schema(AppSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let me = Player(name: "Alex Morgan", isMe: true, cloudUserID: "me", username: "alex")
        let max = Player(name: "Max Keller", cloudUserID: "max", username: "max_keller")
        let tom = Player(name: "Tom Berger", cloudUserID: "tom", username: "tom_berger")
        let local = Player(name: "Lukas Huber")
        for player in [me, max, tom, local] { context.insert(player) }
        let backend = InMemoryBackend(userID: "me", matches: matches, autoResponses: autoResponses)
        return World(context: context, backend: backend, me: me, max: max, tom: tom, local: local)
    }

    /// Badminton 1v1, you win 21–17, 21–19.
    @discardableResult
    private func logBadminton(_ world: World, against friend: Player) -> Match {
        var draft = MatchDraft(sport: Sport(.badminton))
        draft.bestOf = 3
        draft.sets = [SetEntry(scoreA: 21, scoreB: 17), SetEntry(scoreA: 21, scoreB: 19)]
        return draft.insertMatch(me: world.me, friend: friend, into: world.context)
    }

    private func sync(_ world: World) async throws {
        try await MatchSync.sync(me: world.me, context: world.context, backend: world.backend)
    }

    private func record(by creator: String, against opponent: String, version: Int = 1,
                        mode: MatchMode = .oneVsOne) -> MatchRecord {
        MatchRecord(id: UUID(), creatorUserID: creator, version: version, sportType: .badminton, mode: mode,
                    date: Date(), bestOf: 3,
                    participants: [.init(userID: creator, side: .a), .init(userID: opponent, side: .b)],
                    sets: [.init(index: 0, scoreA: 21, scoreB: 15), .init(index: 1, scoreA: 21, scoreB: 18)],
                    createdAt: Date(), updatedAt: Date())
    }

    // MARK: - Status rules

    @Test func opponentsAreTheOtherTeamOrEveryoneInARace() {
        var team = record(by: "me", against: "max", mode: .team)
        team.participants += [.init(userID: "tom", side: .a), .init(userID: "lukas", side: .b)]
        #expect(Set(team.opponentUserIDs) == ["max", "lukas"])

        var race = record(by: "me", against: "max", mode: .race)
        race.participants = [.init(userID: "me", place: 1), .init(userID: "max", place: 2), .init(userID: "tom", place: 3)]
        #expect(Set(race.opponentUserIDs) == ["max", "tom"])
    }

    @Test func confirmedOnlyWhenEveryOpponentConfirmedCurrentVersion() {
        var match = record(by: "me", against: "max", version: 2, mode: .team)
        match.participants.append(.init(userID: "tom", side: .b))
        let maxOK = MatchResponse(matchID: match.id, matchVersion: 2, userID: "max", kind: .confirm)
        let tomOld = MatchResponse(matchID: match.id, matchVersion: 1, userID: "tom", kind: .confirm)
        let tomOK = MatchResponse(matchID: match.id, matchVersion: 2, userID: "tom", kind: .confirm)

        #expect(MatchConfirmation(record: match, responses: []).status == .pending)
        #expect(MatchConfirmation(record: match, responses: [maxOK]).status == .pending)
        // A confirmation of an older version doesn't count.
        #expect(MatchConfirmation(record: match, responses: [maxOK, tomOld]).status == .pending)
        let confirmed = MatchConfirmation(record: match, responses: [maxOK, tomOK])
        #expect(confirmed.status == .confirmed)
        #expect(Set(confirmed.confirmedUserIDs) == ["max", "tom"])
    }

    @Test func oneRejectionRejects() {
        let match = record(by: "me", against: "max")
        let rejected = MatchConfirmation(record: match, responses: [
            MatchResponse(matchID: match.id, matchVersion: 1, userID: "max", kind: .reject,
                          reason: "It was 21–19, not 21–17"),
        ])
        #expect(rejected.status == .rejected)
        #expect(rejected.rejectedByUserID == "max")
        #expect(rejected.rejectionReason == "It was 21–19, not 21–17")
    }

    @Test func answersFromNonOpponentsDontCount() {
        let match = record(by: "me", against: "max")
        let partner = MatchResponse(matchID: match.id, matchVersion: 1, userID: "tom", kind: .confirm)
        let creator = MatchResponse(matchID: match.id, matchVersion: 1, userID: "me", kind: .confirm)
        #expect(MatchConfirmation(record: match, responses: [partner, creator]).status == .pending)
    }

    // MARK: - New matches

    @Test func matchWithOnlineFriendIsPendingAndDoesntCount() throws {
        let world = try world()
        let match = logBadminton(world, against: world.max)
        #expect(match.status == .pending)
        #expect(match.needsUpload)
        #expect(!match.countsTowardRecord)
        #expect(Rivalry.record(of: world.me, against: world.max, in: [match]).matches == 0)
    }

    @Test func matchWithLocalFriendStaysLocal() throws {
        let world = try world()
        let match = logBadminton(world, against: world.local)
        #expect(match.status == .local)
        #expect(!match.needsUpload)
        #expect(match.countsTowardRecord)
    }

    @Test func withoutYourUsernameMatchesStayLocal() throws {
        let world = try world()
        world.me.cloudUserID = nil
        #expect(logBadminton(world, against: world.max).status == .local)
    }

    // MARK: - Upload and status

    @Test func uploadAndConfirm() async throws {
        let world = try world(autoResponses: ["max": (.confirm, nil)])
        let match = logBadminton(world, against: world.max)
        try await sync(world)

        #expect(!match.needsUpload)
        #expect(world.backend.matches[match.id]?.creatorUserID == "me")
        #expect(match.status == .confirmed)
        #expect(match.statusText == "Confirmed")
        #expect(match.countsTowardRecord)
        #expect(Rivalry.record(of: world.me, against: world.max, in: [match]).wins == 1)
    }

    @Test func uploadAndReject() async throws {
        let world = try world(autoResponses: ["max": (.reject, "It was 21–19, not 21–17")])
        let match = logBadminton(world, against: world.max)
        try await sync(world)

        #expect(match.status == .rejected)
        #expect(match.statusText == "Rejected by Max: It was 21–19, not 21–17")
        #expect(!match.countsTowardRecord)
    }

    @Test func noAnswerStaysPending() async throws {
        let world = try world()
        let match = logBadminton(world, against: world.max)
        try await sync(world)
        try await sync(world)

        #expect(match.status == .pending)
        #expect(match.statusText == "Waiting for Max to confirm")
    }

    @Test func editingNeedsNewConfirmation() async throws {
        let world = try world(autoResponses: ["max": (.reject, "Wrong score")])
        let match = logBadminton(world, against: world.max)
        try await sync(world)
        #expect(match.status == .rejected)

        var draft = MatchDraft(match: match, friend: world.max)
        draft.sets = [SetEntry(scoreA: 21, scoreB: 19), SetEntry(scoreA: 21, scoreB: 19)]
        draft.apply(to: match, context: world.context)

        #expect(match.version == 2)
        #expect(match.status == .pending)
        #expect(match.needsUpload)
        #expect(match.rejectionReason == nil)
        try await sync(world)
        #expect(world.backend.matches[match.id]?.version == 2)
        #expect(world.backend.matches[match.id]?.sets.first?.scoreB == 19)
    }

    @Test func teamMatchWaitsForAllOpponents() throws {
        let world = try world()
        let lena = Player(name: "Lena Fischer", cloudUserID: "lena")
        world.context.insert(lena)
        var draft = MatchDraft(sport: Sport(.padel))
        draft.mode = .team
        draft.partners = [world.tom]
        draft.opponents = [lena]
        draft.bestOf = 3
        draft.sets = [SetEntry(scoreA: 6, scoreB: 3), SetEntry(scoreA: 6, scoreB: 4)]
        let match = draft.insertMatch(me: world.me, friend: world.max, into: world.context)

        #expect(match.status == .pending)
        // Tom is your partner, so only Max and Lena confirm.
        #expect(Set(match.waitingParticipants.compactMap(\.player?.name)) == ["Max Keller", "Lena Fischer"])
        #expect(match.statusText == "Waiting for Max and Lena to confirm"
                || match.statusText == "Waiting for Lena and Max to confirm")
    }

    // MARK: - Download

    @Test func matchesOthersLoggedWithYouAreDownloaded() async throws {
        let theirs = record(by: "max", against: "me")
        let world = try world(matches: [theirs])
        try await sync(world)

        let match = try #require(try world.context.fetch(FetchDescriptor<Match>()).first)
        #expect(match.id == theirs.id)
        #expect(match.createdBy?.name == "Max Keller")
        #expect(match.status == .pending)
        #expect(match.statusText == "Waiting for you to confirm")
        #expect(match.side(of: world.max) == .a)
        #expect(match.side(of: world.me) == .b)
        #expect(match.orderedSets.map(\.scoreA) == [21, 21])
        #expect(!match.canEdit(by: world.me))
        #expect(!match.canDelete(by: world.me))
        // Downloading again doesn't create a copy.
        try await sync(world)
        #expect(try world.context.fetch(FetchDescriptor<Match>()).count == 1)
    }

    @Test func yourConfirmationMakesTheirMatchCount() async throws {
        let theirs = record(by: "max", against: "me")
        let world = try world(matches: [theirs])
        try await sync(world)
        try await world.backend.saveResponse(
            MatchResponse(matchID: theirs.id, matchVersion: 1, userID: "me", kind: .confirm))
        try await sync(world)

        let match = try #require(try world.context.fetch(FetchDescriptor<Match>()).first)
        #expect(match.status == .confirmed)
        // Max won 2–0, so it's a loss for you.
        #expect(Rivalry.record(of: world.me, against: world.max, in: [match]).losses == 1)
    }

    @Test func newerVersionReplacesContent() async throws {
        var theirs = record(by: "max", against: "me")
        let world = try world(matches: [theirs])
        try await sync(world)

        // The InMemoryBackend runs as "me"; simulate Max's edit with a fresh backend that holds the new version.
        theirs.version = 2
        theirs.sets = [.init(index: 0, scoreA: 21, scoreB: 10), .init(index: 1, scoreA: 21, scoreB: 11)]
        let edited = InMemoryBackend(userID: "me", matches: [theirs])
        try await MatchSync.sync(me: world.me, context: world.context, backend: edited)

        let match = try #require(try world.context.fetch(FetchDescriptor<Match>()).first)
        #expect(match.version == 2)
        #expect(match.orderedSets.map(\.scoreB) == [10, 11])
        #expect(match.sets.count == 2)
    }

    @Test func matchesWithStrangersAreSkipped() async throws {
        let world = try world(matches: [record(by: "stranger", against: "me")])
        try await sync(world)
        #expect(try world.context.fetch(FetchDescriptor<Match>()).isEmpty)
    }

    @Test func deletedOnlineDisappearsHere() async throws {
        let theirs = record(by: "max", against: "me")
        let world = try world(matches: [theirs])
        try await sync(world)
        try await MatchSync.sync(me: world.me, context: world.context, backend: InMemoryBackend(userID: "me"))
        #expect(try world.context.fetch(FetchDescriptor<Match>()).isEmpty)
    }

    @Test func customSportTravelsWithTheMatch() async throws {
        var theirs = record(by: "max", against: "me")
        let sportID = UUID()
        theirs.sportType = .custom
        theirs.customSport = .init(id: sportID, name: "Darts", symbolName: "target", scoringType: .winLoss,
                                   allowsDraw: false, allowsTeams: false)
        theirs.sets = [.init(index: 0, scoreA: 1, scoreB: 0)]
        let world = try world(matches: [theirs])
        try await sync(world)
        try await sync(world)

        let sports = try world.context.fetch(FetchDescriptor<CustomSport>())
        #expect(sports.map(\.name) == ["Darts"])
        #expect(sports.first?.id == sportID)
        let match = try #require(try world.context.fetch(FetchDescriptor<Match>()).first)
        #expect(match.sport.displayName == "Darts")
        #expect(match.result != nil)
    }

    // MARK: - Rights

    @Test func onlyCreatorCanChangeOnline() async throws {
        let theirs = record(by: "max", against: "me")
        let world = try world(matches: [theirs])
        await #expect(throws: OnlineError.notAllowed) { try await world.backend.saveMatch(theirs) }
        await #expect(throws: OnlineError.notAllowed) { try await world.backend.deleteMatch(id: theirs.id) }
        await #expect(throws: OnlineError.notAllowed) {
            try await world.backend.saveResponse(
                MatchResponse(matchID: theirs.id, matchVersion: 1, userID: "max", kind: .confirm))
        }
    }

    @Test func editAndDeleteRights() throws {
        let world = try world()
        let me = world.me
        let local = logBadminton(world, against: world.local)
        #expect(local.canEdit(by: me) && local.canDelete(by: me))
        let online = logBadminton(world, against: world.max)
        #expect(online.canEdit(by: me) && online.canDelete(by: me))
        online.status = .rejected
        #expect(online.canEdit(by: me) && online.canDelete(by: me))
        // Confirmed: editing becomes a change request, deleting a deletion request (step 4).
        online.status = .confirmed
        #expect(online.canEdit(by: me))
        #expect(!online.canDelete(by: me))
        #expect(online.canRequestDeletion(by: me))
    }

    @Test func creatorDeletesOnline() async throws {
        let world = try world()
        let match = logBadminton(world, against: world.max)
        try await sync(world)
        try await MatchSync.deleteOnline(matchID: match.id, backend: world.backend)
        #expect(world.backend.matches.isEmpty)
    }

    // MARK: - S1

    @Test func friendCardShowsPending() throws {
        let world = try world()
        let match = logBadminton(world, against: world.max)
        let summaries = Rivalry.summaries(of: world.me, friends: [world.max, world.tom],
                                          matches: [match], sortedBy: .name)
        #expect(summaries.first { $0.friend.id == world.max.id }?.hasPending == true)
        #expect(summaries.first { $0.friend.id == world.tom.id }?.hasPending == false)
    }

    @Test func debugTestUsersReact() async throws {
        let backend = InMemoryBackend.withTestUsers(userID: "me")
        #expect(try await backend.fetchMatches().first?.creatorUserID == "test-jonas")
        let max = record(by: "me", against: "test-max")
        let tom = record(by: "me", against: "test-tom")
        let lukas = record(by: "me", against: "test-lukas")
        for match in [max, tom, lukas] { try await backend.saveMatch(match) }
        let responses = try await backend.fetchResponses(matchIDs: [max.id, tom.id, lukas.id])
        #expect(MatchConfirmation(record: max, responses: responses).status == .confirmed)
        #expect(MatchConfirmation(record: tom, responses: responses).status == .rejected)
        #expect(MatchConfirmation(record: lukas, responses: responses).status == .pending)
    }
}
