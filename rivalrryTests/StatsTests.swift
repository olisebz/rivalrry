import Foundation
import Testing
@testable import rivalrry

/// S2c logic: period filter, cumulative wins, donut shares and percent text.
struct StatsTests {

    @Test func periods() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Zurich"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 16)))

        #expect(StatsPeriod.oneMonth.since(now: now, calendar: calendar)
                == calendar.date(from: DateComponents(year: 2026, month: 10, day: 16)))
        #expect(StatsPeriod.threeMonths.since(now: now, calendar: calendar)
                == calendar.date(from: DateComponents(year: 2026, month: 8, day: 16)))
        #expect(StatsPeriod.oneYear.since(now: now, calendar: calendar)
                == calendar.date(from: DateComponents(year: 2025, month: 11, day: 16)))
        #expect(StatsPeriod.all.since(now: now, calendar: calendar) == nil)
        #expect(StatsPeriod.allCases.map(\.rawValue) == ["1M", "3M", "1Y", "All"])
    }

    @Test func modeTitles() {
        #expect(ModeFilter.allCases.map(\.title) == ["1v1 & Race", "Team", "All"])
    }

    @Test func cumulativeWins() throws {
        let f = try Fixture()
        f.add(.badminton, .win, vs: [f.max])
        f.add(.football, .draw, vs: [f.max])
        f.add(.badminton, .loss, vs: [f.max])
        f.add(.badminton, .win, vs: [f.max])

        let points = Rivalry.cumulativeWins(Rivalry.duels(of: f.me, against: f.max, in: f.matches))
        #expect(points.map(\.myWins) == [1, 1, 1, 2])
        #expect(points.map(\.theirWins) == [0, 0, 1, 1])
        #expect(points.map(\.date) == points.map(\.date).sorted())
    }

    @Test func selectedPoint() throws {
        let day: TimeInterval = 86_400
        let start = Date(timeIntervalSince1970: 0)
        let points = [CumulativePoint(date: start, myWins: 1, theirWins: 0),
                      CumulativePoint(date: start + 2 * day, myWins: 1, theirWins: 1)]
        #expect(Rivalry.point(at: start + day, in: points)?.theirWins == 0)
        #expect(Rivalry.point(at: start + 3 * day, in: points)?.theirWins == 1)
        #expect(Rivalry.point(at: start - day, in: points) == points.first)
        #expect(Rivalry.point(at: start, in: []) == nil)
    }

    @Test func outcomeShares() {
        #expect(Rivalry.outcomeShares(Record(wins: 12, losses: 9))
                == [OutcomeShare(outcome: .win, count: 12), OutcomeShare(outcome: .loss, count: 9)])
        #expect(Rivalry.outcomeShares(Record(wins: 1, losses: 0, draws: 2)).map(\.outcome) == [.win, .draw])
        #expect(Rivalry.outcomeShares(Record()).isEmpty)
    }

    @Test func percentText() {
        #expect(Rivalry.percentText(12.0 / 21.0) == "57 %")
        #expect(Rivalry.percentText(1) == "100 %")
        #expect(Rivalry.percentText(0) == "0 %")
        #expect(Rivalry.percentText(nil) == "–")
    }

    @Test func periodFilterOnRecord() throws {
        let f = try Fixture()
        let now = Date()
        f.add(.badminton, .win, vs: [f.max], date: now.addingTimeInterval(-40 * 86_400))
        f.add(.badminton, .loss, vs: [f.max], date: now.addingTimeInterval(-3 * 86_400))
        let lastMonth = DuelFilter(since: StatsPeriod.oneMonth.since(now: now))
        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches, filter: lastMonth) == Record(losses: 1))
        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches) == Record(wins: 1, losses: 1))
    }
}
