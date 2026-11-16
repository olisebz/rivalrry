import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// S4 name rules and S3 editing.
struct FriendFormAndEditTests {

    // MARK: - S4 Add Friend

    @Test func nameRules() throws {
        let f = try Fixture()
        let players = [f.me, f.max, f.tom]
        #expect(FriendForm.validateName("", existing: players) == .empty)
        #expect(FriendForm.validateName("   ", existing: players) == .empty)
        #expect(FriendForm.validateName("Lukas", existing: players) == nil)
        #expect(FriendForm.validateName(String(repeating: "a", count: 20), existing: players) == nil)
        #expect(FriendForm.validateName(String(repeating: "a", count: 21), existing: players) == .tooLong)
        #expect(FriendForm.validateName("max keller", existing: players) == .notUnique)
        #expect(FriendForm.validateName("  Max Keller ", existing: players) == .notUnique)
        // Keeping your own name while editing is fine.
        #expect(FriendForm.validateName("Max Keller", existing: players, editing: f.max) == nil)
        #expect(FriendForm.validateName("Tom Berger", existing: players, editing: f.max) == .notUnique)
    }

    @Test func colorsAvoidRedAndAccent() {
        #expect(!FriendForm.colors.contains("DC2626"))
        #expect(!FriendForm.colors.contains("15803D"))
        #expect(Set(FriendForm.colors).count == FriendForm.colors.count)
    }

    @Test func ensureMeCreatesOnlyOnce() throws {
        let schema = Schema(AppSchema.models)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let first = Player.ensureMe(in: context)
        let second = Player.ensureMe(in: context)
        #expect(first.id == second.id)
        #expect(first.isMe)
        #expect(try context.fetchCount(FetchDescriptor<Player>()) == 1)
    }

    // MARK: - S3 Edit

    @Test func editRoundTripSets() throws {
        let f = try Fixture()
        var draft = MatchDraft(sport: .tennis)
        draft.sets = [SetEntry(scoreA: 6, scoreB: 4), SetEntry(scoreA: 7, scoreB: 6, tiebreakA: 7, tiebreakB: 3)]
        draft.note = "Windy"
        let match = draft.insertMatch(me: f.me, friend: f.max, into: f.context)

        var loaded = MatchDraft(match: match)
        #expect(loaded.sets == draft.sets)
        #expect(loaded.bestOf == 3)
        #expect(loaded.note == "Windy")
        #expect(loaded.date == match.date)

        // Max actually won in three sets.
        loaded.sets = [SetEntry(scoreA: 6, scoreB: 4), SetEntry(scoreA: 3, scoreB: 6), SetEntry(scoreA: 2, scoreB: 6)]
        loaded.note = ""
        loaded.apply(to: match, context: f.context)
        try f.context.save()

        #expect(match.result == MatchResult(outcome: .win(.b), scoreA: 1, scoreB: 2))
        #expect(match.orderedSets.count == 3)
        #expect(match.orderedSets.allSatisfy { $0.tiebreakA == nil })
        #expect(match.note == nil)
        #expect(match.version == 2)
        #expect(try f.context.fetchCount(FetchDescriptor<SetScore>()) == 3)   // old sets are gone
        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches) == Record(losses: 1))
    }

    @Test func editRoundTripOtherTypes() throws {
        let f = try Fixture()

        var penalties = MatchDraft(sport: .penaltyShootout)
        penalties.penaltyShotsPerSide = 3
        penalties.penaltyShots = [true, false, true, false]
        let shootout = penalties.insertMatch(me: f.me, friend: f.max, into: f.context)
        let loadedPenalties = MatchDraft(match: shootout)
        #expect(loadedPenalties.penaltyShotsPerSide == 3)
        #expect(loadedPenalties.penaltyShots == [true, false, true, false])

        var fight = MatchDraft(sport: .boxing)
        fight.fightWinner = .b
        fight.fightMethod = .ko
        fight.fightEndRound = 2
        let bout = fight.insertMatch(me: f.me, friend: f.max, into: f.context)
        let loadedFight = MatchDraft(match: bout)
        #expect(loadedFight.fightEntry == fight.fightEntry)

        var run = MatchDraft(sport: .running)
        run.distanceMeters = 400
        run.timeTextA = "58.1"
        run.dnfB = true
        let race = run.insertMatch(me: f.me, friend: f.max, into: f.context)
        let loadedRun = MatchDraft(match: race)
        #expect(loadedRun.timeTextA == "58.10")
        #expect(loadedRun.dnfB)
        #expect(loadedRun.validate() == run.validate())

        var football = MatchDraft(sport: .football)
        football.scoreA = 2
        football.scoreB = 2
        let game = football.insertMatch(me: f.me, friend: f.max, into: f.context)
        var loadedFootball = MatchDraft(match: game)
        #expect(loadedFootball.scoreA == 2 && loadedFootball.scoreB == 2)
        loadedFootball.scoreA = 3
        loadedFootball.apply(to: game, context: f.context)
        #expect(game.scoreText(for: f.me) == "3 – 2")
        #expect(game.orderedSets.count == 1)
    }

    @Test func editRunningClearsOldDNF() throws {
        let f = try Fixture()
        var run = MatchDraft(sport: .running)
        run.timeTextA = "12.0"
        run.dnfB = true
        let race = run.insertMatch(me: f.me, friend: f.max, into: f.context)

        var edited = MatchDraft(match: race)
        edited.dnfB = false
        edited.timeTextB = "11.5"
        edited.apply(to: race, context: f.context)
        #expect(race.outcome(for: f.me) == .loss)
        #expect(race.participants(on: .b).first?.dnf == false)
    }
}
