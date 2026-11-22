import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Phase 2 step 3: Elo per sport and mode group (plan.md §2.4).
struct EloTests {

    private func change(_ table: EloTable, _ match: Match, _ player: Player) -> Double? {
        table.changes(in: match)[player.id]
    }

    @Test func expectedScore() {
        #expect(Elo.expected(1000, against: 1000) == 0.5)
        #expect(abs(Elo.expected(1200, against: 1000) - 0.7597) < 0.0001)
        #expect(abs(Elo.expected(1000, against: 1200) - 0.2403) < 0.0001)
    }

    @Test func firstWinIsPlusTwenty() throws {
        let f = try Fixture()
        let match = f.add(.badminton, .win, vs: [f.max])
        let table = Elo.table(for: f.matches)

        #expect(change(table, match, f.me) == 20)
        #expect(change(table, match, f.max) == -20)
        #expect(table.ratings[EloKey(playerID: f.me.id, sport: .badminton, group: .singles)] == 1020)
    }

    @Test func unrankedBeforeThreeMatches() throws {
        let f = try Fixture()
        f.add(.badminton, wins: 2, losses: 0, vs: f.max)
        var table = Elo.table(for: f.matches)
        #expect(table.rating(of: f.me, sport: .badminton, group: .singles) == nil)
        #expect(Elo.text(nil) == "Unranked")

        f.add(.badminton, .win, vs: [f.max])
        table = Elo.table(for: f.matches)
        let mine = try #require(table.rating(of: f.me, sport: .badminton, group: .singles))
        let theirs = try #require(table.rating(of: f.max, sport: .badminton, group: .singles))
        #expect(mine > 1000)
        #expect(mine + theirs == 2000)
    }

    @Test func kDropsToTwentyFourAfterTenMatches() throws {
        let f = try Fixture()
        // Draws between equal players change nothing but count as matches.
        for _ in 0..<10 { f.add(.football, .draw, vs: [f.max]) }
        let eleventh = f.add(.football, .win, vs: [f.max])
        let table = Elo.table(for: f.matches)

        #expect(table.rating(of: f.me, sport: .football, group: .singles) == 1012)
        #expect(change(table, eleventh, f.me) == 12)
    }

    @Test func sportsAndGroupsAreSeparate() throws {
        let f = try Fixture()
        f.add(.badminton, wins: 3, losses: 0, vs: f.max)
        f.add(.pingPong, wins: 0, losses: 3, vs: f.max)
        f.add(.badminton, .loss, vs: [f.max, f.lukas], partners: [f.tom])
        let table = Elo.table(for: f.matches)

        #expect(table.rating(of: f.me, sport: .badminton, group: .singles)! > 1000)
        #expect(table.rating(of: f.me, sport: .pingPong, group: .singles)! < 1000)
        #expect(table.history(of: f.me, sport: .badminton, group: .team).map(\.rating) == [980])
        #expect(EloGroup(ModeFilter.all) == .singles)
        #expect(EloGroup(ModeFilter.team) == .team)
        #expect(EloGroup(MatchMode.race) == .singles)
    }

    @Test func teamUsesAverageAndSameChange() throws {
        let f = try Fixture()
        // Me 1020, Tom 1020, Max 980, Lukas 980.
        f.add(.padel, .win, vs: [f.max, f.lukas], partners: [f.tom])
        // Mixed teams: both average 1000, so ±20 for everyone.
        let mixed = f.add(.padel, .win, vs: [f.tom, f.lukas], partners: [f.max])
        var table = Elo.table(for: f.matches)
        #expect(change(table, mixed, f.me) == 20)
        #expect(change(table, mixed, f.max) == 20)
        #expect(change(table, mixed, f.tom) == -20)
        #expect(change(table, mixed, f.lukas) == -20)

        // Now me 1040, Tom 1000, Max 1000, Lukas 960: team averages 1020 vs 980.
        let uneven = f.add(.padel, .win, vs: [f.max, f.lukas], partners: [f.tom])
        table = Elo.table(for: f.matches)
        let expected = 40 * (1 - Elo.expected(1020, against: 980))
        #expect(abs(change(table, uneven, f.me)! - expected) < 0.0001)
        #expect(change(table, uneven, f.tom) == change(table, uneven, f.me))
        #expect(change(table, uneven, f.max) == change(table, uneven, f.lukas))
    }

    @Test func raceSplitsKOverDuels() throws {
        // plan.md §2.3 example: Max 1st, you 2nd, Tom 3rd, Lukas 4th.
        let f = try Fixture()
        var draft = MatchDraft(sport: .goKart)
        draft.racers = [f.max, f.me, f.tom, f.lukas].map { RaceEntry(player: $0) }
        let race = draft.insertMatch(me: f.me, friend: f.max, into: f.context)
        let table = Elo.table(for: f.matches)

        // K / 3 per duel: winner 3 × 40/3 × 0.5 = +20, second 40/3 × 0.5 = +6.67.
        #expect(abs(change(table, race, f.max)! - 20) < 0.0001)
        #expect(abs(change(table, race, f.me)! - 20.0 / 3) < 0.0001)
        #expect(abs(change(table, race, f.tom)! + 20.0 / 3) < 0.0001)
        #expect(abs(change(table, race, f.lukas)! + 20) < 0.0001)
        #expect(Elo.changeText(change(table, race, f.me)!) == "+7")
    }

    @Test func onlyCountingMatchesAndRecalculatedAfterDelete() throws {
        let f = try Fixture()
        f.add(.badminton, .win, vs: [f.max], status: .pending)
        let win = f.add(.badminton, .win, vs: [f.max])
        f.add(.badminton, .loss, vs: [f.max])
        var table = Elo.table(for: f.matches)
        #expect(change(table, win, f.me) == 20)
        #expect(table.history(of: f.me, sport: .badminton, group: .singles).count == 2)

        f.context.delete(win)
        try f.context.save()
        table = Elo.table(for: f.matches)
        #expect(table.history(of: f.me, sport: .badminton, group: .singles).map(\.rating) == [980])
    }

    @Test func texts() {
        #expect(Elo.changeText(14.2) == "+14")
        #expect(Elo.changeText(-14.2) == "\u{2212}14")
        #expect(Elo.changeText(0.3) == "±0")
        #expect(Elo.summary(mine: 1240, theirs: 1180) == "Elo 1240 vs 1180")
        #expect(Elo.summary(mine: 1240, theirs: nil) == "Elo 1240 vs Unranked")
        #expect(Elo.summary(mine: nil, theirs: nil) == "Unranked")

        #expect(Elo.comparisonRow(mine: 1240, theirs: 1180)
            == ComparisonRow(title: "Elo", mine: "1240", theirs: "1180", leader: .me))
        #expect(Elo.comparisonRow(mine: 1000, theirs: 1000).leader == .tied)
        #expect(Elo.comparisonRow(mine: nil, theirs: 1180).leader == nil)
    }
}
