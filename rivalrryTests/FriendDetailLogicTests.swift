import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// S2 logic: score texts, row details, win share, match list and deleting a friend.
struct FriendDetailLogicTests {

    @Test func scoreTextFromBothSides() throws {
        let f = try Fixture()
        let match = f.add(.badminton, .win, vs: [f.max])
        #expect(match.scoreText(for: f.me) == "2 – 0")
        #expect(match.scoreText(for: f.max) == "0 – 2")
        #expect(match.outcome(for: f.me) == .win)
        #expect(match.outcome(for: f.max) == .loss)

        let football = f.add(.football, .loss, vs: [f.max])
        #expect(football.scoreText(for: f.me) == "1 – 2")
        #expect(f.add(.penaltyShootout, .win, vs: [f.max]).scoreText(for: f.me) == "3 – 0")
    }

    @Test func fightScoreText() throws {
        let f = try Fixture()
        #expect(f.add(.boxing, .win, vs: [f.max]).scoreText(for: f.me) == "Points")
        #expect(f.add(.boxing, .draw, vs: [f.max]).scoreText(for: f.me) == "Draw")
    }

    @Test func invalidMatchShowsDash() throws {
        let f = try Fixture()
        let match = f.add(.badminton, .win, vs: [f.max])
        match.sets = []
        #expect(match.scoreText(for: f.me) == "–")
        #expect(match.outcome(for: f.me) == nil)
        #expect(match.scoreText(for: f.tom) == "–")   // not a participant
    }

    @Test func runningTimes() throws {
        let f = try Fixture()
        let match = Match(sportType: .running, distanceMeters: 100)
        f.context.insert(match)
        match.participants = [MatchParticipant(player: f.me, side: .a, timeMs: 12_340),
                              MatchParticipant(player: f.max, side: .b, dnf: true)]
        #expect(match.scoreText(for: f.me) == "12.34 – DNF")
        #expect(match.scoreText(for: f.max) == "DNF – 12.34")

        #expect(TimeText.text(milliseconds: 245_200) == "4:05.20")
        #expect(TimeText.text(milliseconds: 3_723_400) == "1:02:03.40")
        #expect(TimeText.text(milliseconds: 9_050) == "9.05")
    }

    @Test func detailText() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 16)))
        let nov12 = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 18)))
        let lastYear = try #require(calendar.date(from: DateComponents(year: 2025, month: 3, day: 4, hour: 12)))

        let f = try Fixture()
        #expect(f.add(.badminton, .win, vs: [f.max], date: nov12).detailText(now: now) == "Nov 12 · Best of 3")
        #expect(f.add(.football, .win, vs: [f.max], date: nov12).detailText(now: now) == "Nov 12")
        #expect(f.add(.football, .win, vs: [f.max], date: lastYear).detailText(now: now) == "Mar 4, 2025")
    }

    @Test func winShare() {
        #expect(Record(wins: 12, losses: 9).winShare == 12.0 / 21.0)
        #expect(Record(wins: 3, losses: 3, draws: 4).winShare == 0.5)
        #expect(Record(draws: 2).winShare == nil)
        #expect(Record().winShare == nil)
    }

    @Test func matchListIncludesAllStatusesNewestFirst() throws {
        let f = try Fixture()
        let first = f.add(.badminton, .win, vs: [f.max])
        let pending = f.add(.football, .win, vs: [f.max], status: .pending)
        f.add(.tennis, .win, vs: [f.tom])
        let team = f.add(.padel, .win, vs: [f.lukas], partners: [f.max])

        let list = Rivalry.matches(of: f.me, with: f.max, in: f.matches)
        #expect(list.map(\.id) == [team.id, pending.id, first.id])

        let badminton = Rivalry.matches(of: f.me, with: f.max, in: f.matches, sport: .badminton)
        #expect(badminton.map(\.id) == [first.id])
    }

    @Test func sportsPlayedByCount() throws {
        let f = try Fixture()
        f.add(.pingPong, wins: 1, losses: 0, vs: f.max)
        f.add(.badminton, wins: 2, losses: 1, vs: f.max)
        f.add(.tennis, wins: 5, losses: 0, vs: f.tom)
        #expect(Rivalry.sportsPlayed(of: f.me, with: f.max, in: f.matches) == [.badminton, .pingPong])
    }

    @Test func deleteFriendKeepsSharedMatches() throws {
        let f = try Fixture()
        f.add(.badminton, wins: 2, losses: 1, vs: f.max)
        let shared = f.add(.padel, .win, vs: [f.max, f.lukas], partners: [f.tom])
        f.add(.tennis, .win, vs: [f.tom])
        try f.context.save()

        Rivalry.delete(f.max, in: f.context)
        try f.context.save()

        let remaining = f.matches
        #expect(remaining.count == 2)   // shared padel + Tom's tennis
        #expect(remaining.contains { $0.id == shared.id })
        #expect(shared.participants.count == 4)
        #expect(shared.participants.filter { $0.player == nil }.count == 1)
        #expect(try f.context.fetch(FetchDescriptor<Player>()).map(\.name).sorted()
                == ["Alex Morgan", "Lukas Huber", "Tom Berger"])
    }
}
