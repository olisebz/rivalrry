import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// "Elo" section in Profile: one row per sport and group, detail with chart and history.
struct EloTableTests {

    @Test func rowsPerSportAndGroupSortedByElo() throws {
        let f = try Fixture()
        f.add(.badminton, wins: 3, losses: 0, vs: f.max)
        f.add(.pingPong, wins: 0, losses: 3, vs: f.max)
        f.add(.padel, .win, vs: [f.max, f.lukas], partners: [f.tom])

        let entries = Elo.table(for: f.matches).entries(of: f.me, now: f.advanceDate())
        #expect(entries.map(\.title) == ["Badminton", "Ping Pong", "Padel · Team"])
        #expect(entries[0].rating! > 1000)
        #expect(entries[1].rating! < 1000)
        // One team match: unranked, after the ranked rows.
        #expect(entries[2].rating == nil)
        #expect(entries[2].matches == 1)
        #expect(entries.map(\.group) == [.singles, .singles, .team])
    }

    @Test func recentChangeCoversThirtyDays() throws {
        let f = try Fixture()
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_795_348_800)
        let old = calendar.date(byAdding: .day, value: -60, to: now)!
        let recent = calendar.date(byAdding: .day, value: -5, to: now)!
        f.add(.badminton, .win, vs: [f.max], date: old)                         // 1020
        f.add(.badminton, .win, vs: [f.max], date: old.addingTimeInterval(60))
        f.add(.badminton, .loss, vs: [f.max], date: recent)

        let table = Elo.table(for: f.matches)
        let entry = try #require(table.entries(of: f.me, now: now, calendar: calendar).first)
        let points = table.history(of: f.me, sport: .badminton, group: .singles)
        #expect(entry.recentChange == Int((points[2].rating - points[1].rating).rounded()))
        #expect(entry.recentChange! < 0)

        // Nothing in the last 30 days: "–".
        let later = calendar.date(byAdding: .day, value: 90, to: now)!
        #expect(table.entries(of: f.me, now: later, calendar: calendar).first?.recentChange == nil)
        #expect(Elo.recentText(nil) == "–")
        #expect(Elo.recentText(-12) == "\u{2212}12")
    }

    @Test func firstMatchesInWindowCountFromStart() throws {
        let f = try Fixture()
        let now = Date(timeIntervalSince1970: 1_795_348_800)
        f.add(.badminton, .win, vs: [f.max], date: now.addingTimeInterval(-3600))
        let entry = try #require(Elo.table(for: f.matches).entries(of: f.me, now: now).first)
        #expect(entry.recentChange == 20)
    }

    @Test func historyKnowsMatchAndChange() throws {
        let f = try Fixture()
        let first = f.add(.badminton, .win, vs: [f.max])
        let second = f.add(.badminton, .loss, vs: [f.tom])
        let points = Elo.table(for: f.matches).history(of: f.me, sport: .badminton, group: .singles)
        #expect(points.map(\.match?.id) == [first.id, second.id])
        #expect(points[0].change == 20)
        #expect(points[1].rating == 1020 + points[1].change)
    }

    @Test func opponentsText() throws {
        let f = try Fixture()
        let single = f.add(.badminton, .win, vs: [f.max])
        let doubles = f.add(.padel, .win, vs: [f.max, f.lukas], partners: [f.tom])
        #expect(single.opponentsText(for: f.me) == "vs Max")
        #expect(doubles.opponentsText(for: f.me) == "vs Lukas & Max")
        #expect(doubles.opponentsText(for: f.max) == "vs Alex & Tom")

        var kart = MatchDraft(sport: .goKart)
        kart.racers = [f.max, f.me, f.tom, f.lukas].map { RaceEntry(player: $0) }
        let race = kart.insertMatch(me: f.me, friend: f.max, into: f.context)
        #expect(race.opponentsText(for: f.me) == "Race · 4 racers")
    }

    @Test func customSportRowUsesItsName() throws {
        let f = try Fixture()
        let darts = CustomSport(name: "Darts")
        f.context.insert(darts)
        for _ in 0..<3 {
            var draft = MatchDraft(sport: Sport(darts))
            draft.date = f.advanceDate()
            draft.insertMatch(me: f.me, friend: f.max, into: f.context)
        }
        let entry = try #require(Elo.table(for: f.matches).entries(of: f.me).first)
        #expect(entry.title == "Darts")
        #expect(entry.rating != nil)
    }
}
