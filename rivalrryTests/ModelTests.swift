import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Checks the SwiftData model (plan.md §5) in an in-memory store.
struct ModelTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(AppSchema.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    /// Badminton 2–1 for "You" vs. Max, like the mockup.
    private func insertBadmintonMatch(in context: ModelContext) -> (me: Player, max: Player, match: Match) {
        let me = Player(name: "Alex Morgan", isMe: true)
        let max = Player(name: "Max Keller")
        let match = Match(sportType: .badminton, bestOf: 3, createdBy: me)
        context.insert(me)
        context.insert(max)
        context.insert(match)
        match.participants = [
            MatchParticipant(player: me, side: .a),
            MatchParticipant(player: max, side: .b),
        ]
        // Inserted out of order on purpose.
        match.sets = [
            SetScore(index: 2, scoreA: 21, scoreB: 17),
            SetScore(index: 0, scoreA: 21, scoreB: 19),
            SetScore(index: 1, scoreA: 18, scoreB: 21),
        ]
        return (me, max, match)
    }

    @Test func savesMatchWithSetsInOrder() throws {
        let context = try makeContext()
        _ = insertBadmintonMatch(in: context)
        try context.save()

        let matches = try context.fetch(FetchDescriptor<Match>())
        #expect(matches.count == 1)
        let match = try #require(matches.first)
        #expect(match.status == .local)
        #expect(match.participants.count == 2)
        #expect(match.orderedSets.map(\.index) == [0, 1, 2])
        #expect(match.orderedSets.map(\.scoreA) == [21, 18, 21])
    }

    @Test func deletingMatchDeletesDetails() throws {
        let context = try makeContext()
        let (_, _, match) = insertBadmintonMatch(in: context)
        try context.save()

        context.delete(match)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Match>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SetScore>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<MatchParticipant>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Player>()) == 2)
    }

    @Test func deletingPlayerKeepsMatchAsDeletedPlayer() throws {
        let context = try makeContext()
        let (_, max, match) = insertBadmintonMatch(in: context)
        try context.save()

        context.delete(max)
        try context.save()

        #expect(match.participants.count == 2)
        #expect(match.participants.filter { $0.player == nil }.count == 1)
    }

    @Test func savesFightDetail() throws {
        let context = try makeContext()
        let match = Match(sportType: .boxing)
        context.insert(match)
        match.fight = FightDetail(winnerSide: .a, method: .ko, endRound: 2,
                                  roundScores: [RoundScore(round: 1, scoreA: 10, scoreB: 9)])
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<Match>()).first)
        #expect(fetched.fight?.method == .ko)
        #expect(fetched.fight?.totalRounds == 3)
        #expect(fetched.fight?.roundScores.first?.scoreA == 10)
    }
}
