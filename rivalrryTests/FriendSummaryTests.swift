import Foundation
import Testing
@testable import rivalrry

/// S1 logic: sorting, initials and "Last match" dates.
struct FriendSummaryTests {

    @Test func sortOptions() throws {
        let f = try Fixture()
        // Tom: 3 matches, played first. Max: 1 match, played last. Lukas: no matches.
        f.add(.padel, wins: 2, losses: 1, vs: f.tom)
        f.add(.badminton, .win, vs: [f.max])
        let friends = [f.max, f.tom, f.lukas]

        let recent = Rivalry.summaries(of: f.me, friends: friends, matches: f.matches, sortedBy: .recentlyPlayed)
        #expect(recent.map(\.friend.name) == ["Max Keller", "Tom Berger", "Lukas Huber"])

        let byName = Rivalry.summaries(of: f.me, friends: friends, matches: f.matches, sortedBy: .name)
        #expect(byName.map(\.friend.name) == ["Lukas Huber", "Max Keller", "Tom Berger"])

        let byMatches = Rivalry.summaries(of: f.me, friends: friends, matches: f.matches, sortedBy: .mostMatches)
        #expect(byMatches.map(\.friend.name) == ["Tom Berger", "Max Keller", "Lukas Huber"])
        #expect(byMatches.first?.record == Record(wins: 2, losses: 1))
    }

    @Test func friendsWithoutMatchesNewestFirst() throws {
        let f = try Fixture()
        f.tom.createdAt = Date(timeIntervalSince1970: 100)
        f.lukas.createdAt = Date(timeIntervalSince1970: 200)
        let recent = Rivalry.summaries(of: f.me, friends: [f.tom, f.lukas], matches: [], sortedBy: .recentlyPlayed)
        #expect(recent.map(\.friend.name) == ["Lukas Huber", "Tom Berger"])
    }

    @Test func withoutMeEverythingIsEmpty() throws {
        let f = try Fixture()
        f.add(.badminton, .win, vs: [f.max])
        let summaries = Rivalry.summaries(of: nil, friends: [f.max], matches: f.matches, sortedBy: .name)
        #expect(summaries.first?.record == Record())
        #expect(summaries.first?.lastMatch == nil)
    }

    @Test func initials() {
        #expect(Player.initials(for: "Max Keller") == "MK")
        #expect(Player.initials(for: "Max") == "M")
        #expect(Player.initials(for: "anna maria lopez") == "AM")
        #expect(Player.initials(for: "") == "")
        #expect(Player(name: "Max Keller").shortName == "Max")
    }

    @Test func relativeDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Zurich"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 20)))
        func daysAgo(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: now)! }

        #expect(RelativeDay.text(for: now, now: now, calendar: calendar) == "today")
        #expect(RelativeDay.text(for: daysAgo(1), now: now, calendar: calendar) == "yesterday")
        #expect(RelativeDay.text(for: daysAgo(2), now: now, calendar: calendar) == "2 days ago")
        #expect(RelativeDay.text(for: daysAgo(7), now: now, calendar: calendar) == "1 week ago")
        #expect(RelativeDay.text(for: daysAgo(21), now: now, calendar: calendar) == "3 weeks ago")
    }
}
