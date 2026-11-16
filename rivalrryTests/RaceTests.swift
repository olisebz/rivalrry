import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Phase 2 step 2: races – Go-Kart placements and Running with 3+ runners (plan.md §2.2, §2.3).
struct RaceTests {

    /// Go-Kart in finishing order; `dnf` names don't finish.
    private func goKart(_ f: Fixture, order: [Player], dnf: Set<UUID> = [], laps: [UUID: String] = [:]) -> MatchDraft {
        var draft = MatchDraft(sport: .goKart)
        draft.racers = order.map { RaceEntry(player: $0, lapText: laps[$0.id] ?? "", dnf: dnf.contains($0.id)) }
        draft.sortDNFLast()
        return draft
    }

    @Test func goKartExampleFromPlan() throws {
        // plan.md §2.3: You 2nd, Max 1st, Tom 3rd, Lukas 4th.
        let f = try Fixture()
        let race = goKart(f, order: [f.max, f.me, f.tom, f.lukas]).insertMatch(me: f.me, friend: f.max, into: f.context)

        #expect(race.mode == .race)
        #expect(race.participants.allSatisfy { $0.side == nil })
        #expect(race.racePlace(of: f.me) == 2)
        #expect(race.scoreText(for: f.me) == "2nd of 4")
        #expect(race.outcome(for: f.me) == .loss)
        #expect(race.outcome(for: f.max) == .win)

        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches) == Record(losses: 1))
        #expect(Rivalry.record(of: f.me, against: f.tom, in: f.matches) == Record(wins: 1))
        #expect(Rivalry.record(of: f.me, against: f.lukas, in: f.matches) == Record(wins: 1))
        // Races are part of the default record, not "Team".
        #expect(Rivalry.record(of: f.me, against: f.tom, in: f.matches, filter: DuelFilter(mode: .team)) == Record())
    }

    @Test func dnfIsLastAndBothDNFIsDraw() throws {
        let f = try Fixture()
        let draft = goKart(f, order: [f.me, f.max, f.tom, f.lukas], dnf: [f.me.id, f.tom.id])
        #expect(draft.racers.map(\.player.name) == ["Max Keller", "Lukas Huber", "Alex Morgan", "Tom Berger"])
        #expect(draft.myRacePlace == nil)
        #expect(draft.previewText(friendName: "Max") == "You didn't finish")

        let race = draft.insertMatch(me: f.me, friend: f.max, into: f.context)
        #expect(race.scoreText(for: f.me) == "DNF")
        #expect(race.racePlace(of: f.lukas) == 2)
        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches) == Record(losses: 1))
        #expect(Rivalry.record(of: f.me, against: f.tom, in: f.matches) == Record(draws: 1))
    }

    @Test func goKartValidationAndPreview() throws {
        let f = try Fixture()
        var draft = goKart(f, order: [f.tom, f.me, f.max])
        #expect(draft.previewText(friendName: "Max") == "You finish 2nd of 3")

        draft.racers[0].lapText = "fast"
        #expect(draft.validate() == .failure(.invalidLapTime))
        draft.racers[0].lapText = "1:02.345"
        #expect(draft.isValid)

        draft.racers = [RaceEntry(player: f.me)]
        #expect(draft.validate() == .failure(.raceSize))
        #expect(ResultIssue.raceSize.message == "A race needs 2–12 racers.")
    }

    @Test func goKartSetUpAndAvailablePlayers() throws {
        let f = try Fixture()
        var draft = MatchDraft(sport: .goKart)
        draft.setUpRace(me: f.me, friend: f.max)
        #expect(draft.racers.map(\.player.name) == ["Alex Morgan", "Max Keller"])
        draft.racers.append(RaceEntry(player: f.tom))
        #expect(draft.availablePlayers(from: [f.me, f.max, f.tom, f.lukas], friend: f.max).map(\.name) == ["Lukas Huber"])
        #expect(MatchDraft(sport: .running).racers.isEmpty)
    }

    @Test func fastestLapsAreSaved() throws {
        let f = try Fixture()
        let race = goKart(f, order: [f.me, f.max], laps: [f.me.id: "1:02.345"])
            .insertMatch(me: f.me, friend: f.max, into: f.context)
        let mine = try #require(race.participants.first { $0.player?.id == f.me.id })
        #expect(mine.fastestLapMs == 62_345)
        #expect(mine.place == 1)
        #expect(TimeText.lap(milliseconds: 61_870) == "1:01.870")
    }

    @Test func runningRaceWithTiesAndDNF() throws {
        let f = try Fixture()
        var draft = MatchDraft(sport: .running)
        draft.distanceMeters = 100
        draft.timeTextA = "12.40"
        draft.timeTextB = "12.40"       // same time as you: same place, draw
        draft.extraRunners = [RaceEntry(player: f.tom, timeText: "11.90"), RaceEntry(player: f.lukas, dnf: true)]
        #expect(draft.isRace)
        #expect(draft.previewText(friendName: "Max") == "You finish 2nd of 4")

        let race = draft.insertMatch(me: f.me, friend: f.max, into: f.context)
        #expect(race.mode == .race)
        #expect(race.distanceMeters == 100)
        #expect(race.racePlace(of: f.tom) == 1)
        #expect(race.racePlace(of: f.me) == 2)
        #expect(race.racePlace(of: f.max) == 2)
        #expect(race.racePlace(of: f.lukas) == nil)

        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches) == Record(draws: 1))
        #expect(Rivalry.record(of: f.me, against: f.tom, in: f.matches) == Record(losses: 1))
        #expect(Rivalry.record(of: f.me, against: f.lukas, in: f.matches) == Record(wins: 1))
    }

    @Test func runningRaceNeedsAllTimes() throws {
        let f = try Fixture()
        var draft = MatchDraft(sport: .running)
        draft.timeTextA = "12.40"
        draft.timeTextB = "12.90"
        draft.extraRunners = [RaceEntry(player: f.tom)]
        #expect(draft.validate() == .failure(.missingTime))
        draft.extraRunners[0].dnf = true
        #expect(draft.isValid)
        // Without extra runners it's a normal 1v1 again.
        draft.extraRunners = []
        #expect(!draft.isRace)
        #expect(draft.previewText(friendName: "Max") == "You win")
    }

    @Test func headToHeadForGoKart() throws {
        let f = try Fixture()
        goKart(f, order: [f.me, f.max, f.tom], laps: [f.me.id: "1:02.000", f.max.id: "1:01.500"])
            .insertMatch(me: f.me, friend: f.max, into: f.context)
        goKart(f, order: [f.tom, f.max, f.lukas, f.me]).insertMatch(me: f.me, friend: f.max, into: f.context)

        let duels = Rivalry.duels(of: f.me, against: f.max, in: f.matches)
        let rows = Dictionary(uniqueKeysWithValues: SportComparison.rows(for: .goKart, duels: duels, me: f.me).map { ($0.title, $0) })
        #expect(rows["Wins"] == ComparisonRow(title: "Wins", mine: "1", theirs: "1", leader: .tied))
        // You: 1st and 4th = 2.5, Max: 2nd and 2nd = 2.0 → Max is better.
        #expect(rows["Avg. place"] == ComparisonRow(title: "Avg. place", mine: "2.5", theirs: "2.0", leader: .friend))
        #expect(rows["Podiums"] == ComparisonRow(title: "Podiums", mine: "1", theirs: "2", leader: .friend))
        #expect(rows["Best lap"] == ComparisonRow(title: "Best lap", mine: "1:02.000", theirs: "1:01.500", leader: .friend))
    }

    @Test func detailTextForRaces() throws {
        let f = try Fixture()
        var draft = goKart(f, order: [f.me, f.max, f.tom])
        let nov12 = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 18)))
        draft.date = nov12
        let race = draft.insertMatch(me: f.me, friend: f.max, into: f.context)
        let now = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 16)))
        #expect(race.detailText(now: now) == "Nov 12 · 3 racers")
    }

    @Test func ordinals() {
        let texts = [1, 2, 3, 4, 11, 12, 13, 21, 22, 101].map { Ordinal.text($0) }
        #expect(texts == ["1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st", "22nd", "101st"])
    }

    @Test func goKartIsLoggable() {
        #expect(SportType.phase1Sports.contains(.goKart))
    }
}
