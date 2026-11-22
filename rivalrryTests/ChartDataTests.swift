import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Phase 2 step 5: "Score Margin", "Activity" and the Running times chart (plan.md §4 S2c).
struct ChartDataTests {

    private func duels(_ f: Fixture, _ sport: Sport? = nil) -> [Duel] {
        Rivalry.duels(of: f.me, against: f.max, in: f.matches, filter: DuelFilter(sport: sport))
    }

    private func run(_ f: Fixture, _ mine: String, _ theirs: String, distance: Int = 100) {
        var draft = MatchDraft(sport: .running)
        draft.timeTextA = mine
        draft.timeTextB = theirs
        draft.distanceMeters = distance
        draft.date = f.advanceDate()
        _ = draft.insertMatch(me: f.me, friend: f.max, into: f.context)
    }

    @Test func setMarginIsPointDifference() throws {
        let f = try Fixture()
        let win = f.add(.badminton, .win, vs: [f.max])
        win.sets = [SetScore(index: 0, scoreA: 21, scoreB: 19), SetScore(index: 1, scoreA: 21, scoreB: 18)]
        f.add(.badminton, .loss, vs: [f.max])   // 0–21, 0–21

        let points = Rivalry.margins(duels(f, .badminton), me: f.me)
        #expect(points.map(\.margin) == [5, -42])
        #expect(points.map(\.outcome) == [.win, .loss])
    }

    @Test func pointsAndPenaltyMargins() throws {
        let f = try Fixture()
        let football = f.add(.football, .win, vs: [f.max])
        football.sets = [SetScore(index: 0, scoreA: 4, scoreB: 1)]
        f.add(.football, .draw, vs: [f.max])
        f.add(.penaltyShootout, .loss, vs: [f.max])

        #expect(Rivalry.margins(duels(f, .football), me: f.me).map(\.margin) == [3, 0])
        #expect(Rivalry.margins(duels(f, .penaltyShootout), me: f.me).map(\.margin) == [-3])
    }

    @Test func noMarginForFights() throws {
        let f = try Fixture()
        f.add(.boxing, .win, vs: [f.max])
        #expect(Rivalry.margins(duels(f), me: f.me).isEmpty)
    }

    @Test func teamMatchCountsOnce() throws {
        let f = try Fixture()
        f.add(.padel, .win, vs: [f.max, f.lukas], partners: [f.tom])
        let teamDuels = Rivalry.duels(of: f.me, against: f.max, in: f.matches, filter: DuelFilter(mode: .all))
            + Rivalry.duels(of: f.me, against: f.lukas, in: f.matches, filter: DuelFilter(mode: .all))
        #expect(teamDuels.count == 2)
        #expect(Rivalry.uniqueMatches(teamDuels).count == 1)
    }

    @Test func activityWeeks() throws {
        let f = try Fixture()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2   // Monday
        // Wed 2026-11-04 … Sun 2026-11-22.
        let start = Date(timeIntervalSince1970: 1_793_750_400)
        let now = Date(timeIntervalSince1970: 1_795_348_800)
        let day = { (offset: Int) in calendar.date(byAdding: .day, value: offset, to: start)! }
        f.add(.badminton, .win, vs: [f.max], date: day(0).addingTimeInterval(3600))
        f.add(.badminton, .loss, vs: [f.max], date: day(0).addingTimeInterval(7200))
        f.add(.badminton, .win, vs: [f.max], date: day(9))

        let weeks = Rivalry.activityWeeks(duels(f), from: start, now: now, calendar: calendar)
        #expect(weeks.count == 3)
        #expect(weeks.allSatisfy { $0.count == 7 })
        // Mon and Tue before the start are empty cells.
        #expect(weeks[0][0] == nil && weeks[0][1] == nil)
        #expect(weeks[0][2]?.matches == 2)
        #expect(weeks[1][4]?.matches == 1)
        #expect(weeks[2][6]?.date == calendar.startOfDay(for: now))
        #expect(weeks.joined().compactMap { $0 }.filter { $0.matches > 0 }.count == 2)
    }

    @Test func activityStart() {
        let now = Date(timeIntervalSince1970: 1_795_348_800)
        let calendar = Calendar(identifier: .gregorian)
        #expect(Rivalry.activityStart(for: .all, now: now, calendar: calendar)
            == calendar.date(byAdding: .year, value: -1, to: now))
        #expect(Rivalry.activityStart(for: .oneMonth, now: now, calendar: calendar)
            == calendar.date(byAdding: .month, value: -1, to: now))
    }

    @Test func runTimesPerDistance() throws {
        let f = try Fixture()
        run(f, "12.40", "12.90")
        run(f, "12.10", "12.50")
        run(f, "25:00.00", "24:30.00", distance: 5000)

        let runs = Rivalry.runTimes(duels(f, .running), me: f.me, friend: f.max)
        #expect(runs[100]?.map(\.mine) == [12_400, 12_100])
        #expect(runs[100]?.map(\.theirs) == [12_900, 12_500])
        #expect(runs[5000]?.first?.theirs == 1_470_000)
        // Most runs first.
        #expect(Rivalry.distancesByRuns(runs) == [100, 5000])
    }
}
