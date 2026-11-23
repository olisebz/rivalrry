import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Phase 3 step 4: S6 Confirm / Reject, changes to confirmed matches, deletion requests and Remind.
struct MatchRequestTests {

    private struct World {
        let context: ModelContext
        let backend: InMemoryBackend
        let me: Player
        let max: Player
        let tom: Player
    }

    private func world(autoResponses: [String: (MatchResponse.Kind, String?)] = [:],
                       matches: [MatchRecord] = []) throws -> World {
        let container = try ModelContainer(for: Schema(AppSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let me = Player(name: "Alex Morgan", isMe: true, cloudUserID: "me", username: "alex")
        let max = Player(name: "Max Keller", cloudUserID: "max", username: "max_keller")
        let tom = Player(name: "Tom Berger", cloudUserID: "tom", username: "tom_berger")
        for player in [me, max, tom] { context.insert(player) }
        let backend = InMemoryBackend(userID: "me", matches: matches, autoResponses: autoResponses)
        return World(context: context, backend: backend, me: me, max: max, tom: tom)
    }

    private func sync(_ world: World) async throws {
        try await MatchSync.sync(me: world.me, context: world.context, backend: world.backend)
    }

    private func matches(_ world: World) throws -> [Match] {
        try world.context.fetch(FetchDescriptor<Match>())
    }

    /// Your Badminton match, 21–17, 21–19 (2 – 0 for you).
    @discardableResult
    private func logBadminton(_ world: World, against friend: Player) -> Match {
        var draft = MatchDraft(sport: Sport(.badminton))
        draft.bestOf = 3
        draft.sets = [SetEntry(scoreA: 21, scoreB: 17), SetEntry(scoreA: 21, scoreB: 19)]
        return draft.insertMatch(me: world.me, friend: friend, into: world.context)
    }

    /// The same match edited to a 1 – 2 loss.
    private func lossDraft(for match: Match, friend: Player) -> MatchDraft {
        var draft = MatchDraft(match: match, friend: friend)
        draft.sets = [SetEntry(scoreA: 21, scoreB: 17), SetEntry(scoreA: 15, scoreB: 21), SetEntry(scoreA: 18, scoreB: 21)]
        return draft
    }

    /// Max's match with you: Max wins 21–15, 21–18.
    private func maxRecord(version: Int = 1) -> MatchRecord {
        MatchRecord(id: UUID(), creatorUserID: "max", version: version, sportType: .badminton, mode: .oneVsOne,
                    date: Date(), bestOf: 3,
                    participants: [.init(userID: "max", side: .a), .init(userID: "me", side: .b)],
                    sets: [.init(index: 0, scoreA: 21, scoreB: 15), .init(index: 1, scoreA: 21, scoreB: 18)],
                    createdAt: Date(), updatedAt: Date())
    }

    // MARK: - Confirm / Reject

    @Test func confirmMakesItCount() async throws {
        let world = try world(matches: [maxRecord()])
        try await sync(world)
        let match = try #require(try matches(world).first)
        #expect(MatchRequests(matches: [match], me: world.me).toConfirm == [match])
        #expect(MatchRequests(matches: [match], me: world.me).actionCount == 1)

        try await MatchSync.confirm(match, me: world.me, backend: world.backend)
        try await sync(world)

        #expect(match.status == .confirmed)
        #expect(Rivalry.record(of: world.me, against: world.max, in: [match]).losses == 1)
        #expect(MatchRequests(matches: [match], me: world.me).toConfirm.isEmpty)
    }

    @Test func rejectNeedsAReason() async throws {
        let world = try world(matches: [maxRecord()])
        try await sync(world)
        let match = try #require(try matches(world).first)

        try await MatchSync.reject(match, reason: "   ", me: world.me, backend: world.backend)
        #expect(world.backend.responses.isEmpty)

        try await MatchSync.reject(match, reason: "It was 21–19, not 21–15", me: world.me, backend: world.backend)
        try await sync(world)
        #expect(match.status == .rejected)
        #expect(world.backend.responses.first?.reason == "It was 21–19, not 21–15")
        #expect(match.statusText == "Rejected by you: It was 21–19, not 21–15")
        #expect(!match.countsTowardRecord)
        #expect(MatchRequests(matches: [match], me: world.me).toConfirm.isEmpty)
    }

    @Test func yourOwnMatchIsNotToConfirm() throws {
        let world = try world()
        let match = logBadminton(world, against: world.max)
        let requests = MatchRequests(matches: [match], me: world.me)
        #expect(requests.toConfirm.isEmpty)
        #expect(requests.waitingForOthers == [match])
        #expect(requests.actionCount == 0)
    }

    // MARK: - Changing a confirmed match

    @Test func changeKeepsOldResultUntilConfirmed() async throws {
        let world = try world()
        let match = logBadminton(world, against: world.max)
        try await sync(world)
        world.backend.receive(MatchResponse(matchID: match.id, matchVersion: 1, userID: "max", kind: .confirm))
        try await sync(world)
        #expect(match.status == .confirmed)

        MatchSync.proposeChange(lossDraft(for: match, friend: world.max), to: match, context: world.context)

        // The old 2 – 0 win still counts.
        #expect(match.status == .confirmed)
        #expect(match.version == 1)
        #expect(match.orderedSets.count == 2)
        #expect(Rivalry.record(of: world.me, against: world.max, in: [match]).wins == 1)
        #expect(match.pendingChange?.record.version == 2)
        #expect(match.changeScoreText(for: world.me) == "1 – 2")
        #expect(match.changeText == "Change waiting for Max to confirm")

        try await sync(world)
        #expect(world.backend.matches[match.id]?.proposedChange?.version == 2)
        #expect(match.status == .confirmed)
        #expect(MatchRequests(matches: [match], me: world.me).waitingForOthers == [match])
    }

    @Test func confirmedChangeReplacesOldResult() async throws {
        let world = try world(autoResponses: ["max": (.confirm, nil)])
        let match = logBadminton(world, against: world.max)
        try await sync(world)
        #expect(match.status == .confirmed)

        MatchSync.proposeChange(lossDraft(for: match, friend: world.max), to: match, context: world.context)
        try await sync(world)

        #expect(match.version == 2)
        #expect(match.orderedSets.count == 3)
        #expect(match.pendingChange == nil)
        #expect(match.status == .confirmed)
        #expect(Rivalry.record(of: world.me, against: world.max, in: [match]).losses == 1)
        // The merged record online has no open change anymore.
        let online = try #require(world.backend.matches[match.id])
        #expect(online.version == 2)
        #expect(online.proposedChange == nil)
        #expect(online.sets.count == 3)
    }

    @Test func rejectedChangeKeepsOldResult() async throws {
        let world = try world()
        let match = logBadminton(world, against: world.max)
        try await sync(world)
        world.backend.receive(MatchResponse(matchID: match.id, matchVersion: 1, userID: "max", kind: .confirm))
        try await sync(world)

        MatchSync.proposeChange(lossDraft(for: match, friend: world.max), to: match, context: world.context)
        try await sync(world)
        world.backend.receive(MatchResponse(matchID: match.id, matchVersion: 2, userID: "max", kind: .reject,
                                            reason: "We didn't play a third set"))
        try await sync(world)

        // The rejection of version 2 doesn't touch the confirmation of version 1.
        #expect(match.status == .confirmed)
        #expect(match.version == 1)
        #expect(match.changeText == "Change rejected by Max: We didn't play a third set")
        #expect(Rivalry.record(of: world.me, against: world.max, in: [match]).wins == 1)

        // A new change gets a new version.
        MatchSync.proposeChange(lossDraft(for: match, friend: world.max), to: match, context: world.context)
        #expect(match.pendingChange?.record.version == 3)
    }

    @Test func changeFromSomeoneElseIsToConfirm() async throws {
        var theirs = maxRecord()
        var change = theirs
        change.version = 2
        change.sets = [.init(index: 0, scoreA: 19, scoreB: 21), .init(index: 1, scoreA: 18, scoreB: 21)]
        theirs.proposedChange = change
        let world = try world(matches: [theirs])
        world.backend.receive(MatchResponse(matchID: theirs.id, matchVersion: 1, userID: "me", kind: .confirm))
        try await sync(world)

        let match = try #require(try matches(world).first)
        #expect(match.status == .confirmed)
        #expect(match.needsConfirmation(by: world.me))
        #expect(match.changeScoreText(for: world.me) == "2 – 0")
        #expect(match.changeText == "Change waiting for you to confirm")

        try await MatchSync.confirm(match, me: world.me, backend: world.backend)
        #expect(world.backend.responses.contains { $0.matchVersion == 2 && $0.kind == .confirm })
        try await sync(world)
        #expect(match.version == 2)
        #expect(match.pendingChange == nil)
        #expect(Rivalry.record(of: world.me, against: world.max, in: [match]).wins == 1)
    }

    // MARK: - Deletion requests

    @Test func deletionNeedsEveryoneElse() async throws {
        let world = try world(autoResponses: ["max": (.confirm, nil)])
        let match = logBadminton(world, against: world.max)
        try await sync(world)
        #expect(match.canRequestDeletion(by: world.me))
        #expect(!match.canDelete(by: world.me))

        try await MatchSync.requestDeletion(match, me: world.me, backend: world.backend)
        // Max (test user who confirms) approves right away.
        try await sync(world)

        #expect(try matches(world).isEmpty)
        #expect(world.backend.matches.isEmpty)
    }

    @Test func declinedDeletionKeepsTheMatch() async throws {
        let world = try world(autoResponses: ["max": (.confirm, nil)])
        let match = logBadminton(world, against: world.max)
        try await sync(world)
        let id = match.id
        let requestedAt = Date()
        world.backend.receive(MatchResponse(matchID: id, matchVersion: 1, userID: "me", kind: .requestDelete,
                                            createdAt: requestedAt))
        try await sync(world)
        #expect(match.deletionText(me: world.me) == "Waiting for Max to approve deletion")
        #expect(!match.canRequestDeletion(by: world.me))
        #expect(!match.canEdit(by: world.me))

        world.backend.receive(MatchResponse(matchID: id, matchVersion: 1, userID: "max", kind: .declineDelete,
                                            createdAt: requestedAt.addingTimeInterval(5)))
        try await sync(world)
        #expect(try matches(world).count == 1)
        #expect(match.deletionRequest == nil)
        #expect(match.canRequestDeletion(by: world.me))
    }

    @Test func opponentAsksToDeleteYourMatch() async throws {
        let world = try world(autoResponses: ["max": (.confirm, nil)])
        let match = logBadminton(world, against: world.max)
        try await sync(world)
        world.backend.receive(MatchResponse(matchID: match.id, matchVersion: 1, userID: "max", kind: .requestDelete))
        try await sync(world)

        #expect(match.needsDeletionAnswer(by: world.me))
        #expect(match.deletionText(me: world.me) == "Max wants to delete this match")
        #expect(MatchRequests(matches: [match], me: world.me).deletionRequests == [match])

        try await MatchSync.answerDeletion(match, approve: true, me: world.me, backend: world.backend)
        try await sync(world)
        #expect(try matches(world).isEmpty)
        #expect(world.backend.matches.isEmpty)
    }

    @Test func deletionRules() {
        var record = maxRecord()
        record.participants.append(.init(userID: "tom", side: .a))
        let request = Date()
        let responses = [
            // Answers from before the request and from outsiders don't count.
            MatchResponse(matchID: record.id, matchVersion: 1, userID: "me", kind: .approveDelete,
                          createdAt: request.addingTimeInterval(-10)),
            MatchResponse(matchID: record.id, matchVersion: 1, userID: "max", kind: .requestDelete, createdAt: request),
            MatchResponse(matchID: record.id, matchVersion: 1, userID: "stranger", kind: .declineDelete,
                          createdAt: request.addingTimeInterval(5)),
        ]
        let open = try! #require(DeletionRequest(record: record, responses: responses))
        // Tom is Max's partner: he neither confirms nor approves.
        #expect(open.approverUserIDs == ["me"])
        #expect(!open.isApproved)
        // Tom (partner) can't ask either.
        let tomAsks = [MatchResponse(matchID: record.id, matchVersion: 1, userID: "tom", kind: .requestDelete)]
        #expect(DeletionRequest(record: record, responses: tomAsks) == nil)
    }

    // MARK: - Remind

    @Test func remindOnceEvery24Hours() async throws {
        let world = try world()
        let match = logBadminton(world, against: world.max)
        let now = Date()
        #expect(match.canRemind(by: world.me, now: now))

        MatchSync.remind(match, me: world.me, now: now)
        #expect(!match.canRemind(by: world.me, now: now.addingTimeInterval(23 * 3600)))
        #expect(match.canRemind(by: world.me, now: now.addingTimeInterval(24 * 3600)))
        try await sync(world)
        #expect(world.backend.matches[match.id]?.remindedAt == now)
        #expect(RemindText.text(for: now.addingTimeInterval(-3 * 3600), now: now) == "Reminded 3 hours ago")
    }

    @Test func noRemindForConfirmedOrOthersMatches() async throws {
        let world = try world(autoResponses: ["max": (.confirm, nil)], matches: [maxRecord()])
        let mine = logBadminton(world, against: world.max)
        try await sync(world)
        #expect(mine.status == .confirmed)
        #expect(!mine.canRemind(by: world.me))
        let theirs = try #require(try matches(world).first { $0.id != mine.id })
        #expect(!theirs.canRemind(by: world.me))
    }

    // MARK: - Backend

    @Test func answersAreKeptPerVersion() async throws {
        let world = try world(matches: [maxRecord()])
        let id = try #require(world.backend.matches.keys.first)
        try await world.backend.saveResponse(MatchResponse(matchID: id, matchVersion: 1, userID: "me", kind: .confirm))
        try await world.backend.saveResponse(MatchResponse(matchID: id, matchVersion: 2, userID: "me", kind: .reject,
                                                           reason: "No"))
        try await world.backend.saveResponse(MatchResponse(matchID: id, matchVersion: 2, userID: "me", kind: .confirm))
        try await world.backend.saveResponse(MatchResponse(matchID: id, matchVersion: 1, userID: "me", kind: .requestDelete))
        let kinds = world.backend.responses.map { "\($0.matchVersion)-\($0.kind.rawValue)" }.sorted()
        #expect(kinds == ["1-confirm", "1-requestDelete", "2-confirm"])
    }
}
