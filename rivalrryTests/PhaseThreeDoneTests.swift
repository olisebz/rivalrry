import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Phase 3 "Done when" (plan.md §8): You log a match, Max (test user) confirms it, and it appears in both
/// your stats. Max's phone is simulated with a second store and a backend that holds what yours uploaded.
struct PhaseThreeDoneTests {

    private func store() throws -> ModelContext {
        ModelContext(try ModelContainer(for: Schema(AppSchema.models),
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    @Test func loggedMatchConfirmedByMaxCountsForBoth() async throws {
        // Your phone.
        let mine = try store()
        let me = Player(name: "Alex Morgan", isMe: true, cloudUserID: "alex", username: "alex")
        let max = Player(name: "Max Keller", cloudUserID: "max", username: "max_keller")
        mine.insert(me)
        mine.insert(max)
        let yourBackend = InMemoryBackend(userID: "alex")

        var draft = MatchDraft(sport: Sport(.badminton))
        draft.bestOf = 3
        draft.sets = [SetEntry(scoreA: 21, scoreB: 17), SetEntry(scoreA: 21, scoreB: 19)]
        let match = draft.insertMatch(me: me, friend: max, into: mine)
        try await MatchSync.sync(me: me, context: mine, backend: yourBackend)
        #expect(match.status == .pending)
        #expect(Rivalry.record(of: me, against: max, in: [match]).matches == 0)

        // Max's phone: sees your match under "To confirm" and confirms it.
        let his = try store()
        let maxHimself = Player(name: "Max Keller", isMe: true, cloudUserID: "max", username: "max_keller")
        let alex = Player(name: "Alex Morgan", cloudUserID: "alex", username: "alex")
        his.insert(maxHimself)
        his.insert(alex)
        let maxBackend = InMemoryBackend(userID: "max", matches: Array(yourBackend.matches.values))
        try await MatchSync.sync(me: maxHimself, context: his, backend: maxBackend)
        let hisCopy = try #require(try his.fetch(FetchDescriptor<Match>()).first)
        #expect(MatchRequests(matches: [hisCopy], me: maxHimself).toConfirm == [hisCopy])
        try await MatchSync.confirm(hisCopy, me: maxHimself, backend: maxBackend)
        try await MatchSync.sync(me: maxHimself, context: his, backend: maxBackend)

        // His answer reaches your backend.
        for response in maxBackend.responses { yourBackend.receive(response) }
        try await MatchSync.sync(me: me, context: mine, backend: yourBackend)

        // Both stats: a win for you, a loss for Max.
        #expect(match.status == .confirmed)
        #expect(hisCopy.status == .confirmed)
        #expect(Rivalry.record(of: me, against: max, in: [match]).wins == 1)
        #expect(Rivalry.record(of: maxHimself, against: alex, in: [hisCopy]).losses == 1)
    }
}
