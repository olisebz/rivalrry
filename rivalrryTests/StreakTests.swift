import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Phase 2 step 4: streaks and highlights (plan.md §4 S1, S2a, S2c).
struct StreakTests {

    private func duels(_ f: Fixture, filter: DuelFilter = DuelFilter()) -> [Duel] {
        Rivalry.duels(of: f.me, against: f.max, in: f.matches, filter: filter)
    }

    @Test func currentStreak() throws {
        let f = try Fixture()
        #expect(Rivalry.currentStreak([]) == nil)

        f.add(.badminton, wins: 1, losses: 0, vs: f.max)
        f.add(.badminton, wins: 0, losses: 2, vs: f.max)
        #expect(Rivalry.currentStreak(duels(f)) == Streak(kind: .losses, count: 2))

        f.add(.badminton, wins: 3, losses: 0, vs: f.max)
        #expect(Rivalry.currentStreak(duels(f)) == Streak(kind: .wins, count: 3))
    }

    @Test func drawEndsStreak() throws {
        let f = try Fixture()
        f.add(.football, wins: 3, losses: 0, vs: f.max)
        f.add(.football, .draw, vs: [f.max])
        #expect(Rivalry.currentStreak(duels(f)) == nil)
        #expect(Rivalry.longestWinStreak(duels(f)) == Streak(kind: .wins, count: 3))

        f.add(.football, .win, vs: [f.max])
        #expect(Rivalry.currentStreak(duels(f)) == Streak(kind: .wins, count: 1))
    }

    @Test func longestWinStreak() throws {
        let f = try Fixture()
        #expect(Rivalry.longestWinStreak([]) == nil)
        f.add(.badminton, wins: 0, losses: 4, vs: f.max)
        #expect(Rivalry.longestWinStreak(duels(f)) == nil)

        f.add(.badminton, wins: 4, losses: 1, vs: f.max)
        f.add(.badminton, wins: 2, losses: 0, vs: f.max)
        #expect(Rivalry.longestWinStreak(duels(f)) == Streak(kind: .wins, count: 4))
    }

    @Test func cardStreakFromThree() throws {
        let f = try Fixture()
        f.add(.badminton, wins: 2, losses: 0, vs: f.max)
        #expect(Rivalry.cardStreak(of: f.me, against: f.max, in: f.matches) == nil)

        f.add(.pingPong, .win, vs: [f.max])
        let streak = try #require(Rivalry.cardStreak(of: f.me, against: f.max, in: f.matches))
        #expect(streak.rowText == "3 wins in a row")

        // Team matches aren't part of the default record.
        f.add(.badminton, .loss, vs: [f.max, f.lukas], partners: [f.tom])
        #expect(Rivalry.cardStreak(of: f.me, against: f.max, in: f.matches)?.count == 3)

        let summary = try #require(Rivalry.summaries(of: f.me, friends: [f.max], matches: f.matches,
                                                     sortedBy: .name).first)
        #expect(summary.streak?.count == 3)
    }

    @Test func texts() {
        #expect(Streak(kind: .wins, count: 1).shortText == "1 win")
        #expect(Streak(kind: .wins, count: 4).rowText == "4 wins in a row")
        #expect(Streak(kind: .losses, count: 1).shortText == "1 loss")
        #expect(Streak(kind: .losses, count: 3).rowText == "3 losses in a row")
    }

    @Test func closestAndBiggestWinInSets() throws {
        let f = try Fixture()
        let clear = f.add(.badminton, .win, vs: [f.max])              // 21–0, 21–0
        let close = f.add(.badminton, .win, vs: [f.max])
        close.sets = [SetScore(index: 0, scoreA: 21, scoreB: 19), SetScore(index: 1, scoreA: 19, scoreB: 21),
                      SetScore(index: 2, scoreA: 22, scoreB: 20)]
        f.add(.badminton, .loss, vs: [f.max])

        let all = duels(f, filter: DuelFilter(sport: .badminton))
        #expect(Rivalry.closestWin(all, me: f.me)?.match.id == close.id)
        #expect(Rivalry.biggestWin(all, me: f.me)?.match.id == clear.id)
        let margin = try #require(Rivalry.closestWin(all, me: f.me)?.margin)
        #expect(margin.primary == 1 && margin.secondary == 2)
    }

    @Test func pointsMarginAndTies() throws {
        let f = try Fixture()
        let older = f.add(.football, .win, vs: [f.max])
        older.sets = [SetScore(index: 0, scoreA: 3, scoreB: 2)]
        let big = f.add(.football, .win, vs: [f.max])
        big.sets = [SetScore(index: 0, scoreA: 5, scoreB: 1)]
        let newer = f.add(.football, .win, vs: [f.max])
        newer.sets = [SetScore(index: 0, scoreA: 1, scoreB: 0)]

        let all = duels(f, filter: DuelFilter(sport: .football))
        #expect(Rivalry.biggestWin(all, me: f.me)?.match.id == big.id)
        // Same margin of 1: the more recent one.
        #expect(Rivalry.closestWin(all, me: f.me)?.match.id == newer.id)
    }

    @Test func noMarginForFightsAndRaces() throws {
        let f = try Fixture()
        f.add(.boxing, .win, vs: [f.max])
        #expect(!Rivalry.hasMargin(.boxing))
        #expect(!Rivalry.hasMargin(.goKart))
        #expect(Rivalry.hasMargin(.penaltyShootout))
        #expect(Rivalry.winHighlights(duels(f), me: f.me).isEmpty)
    }
}
