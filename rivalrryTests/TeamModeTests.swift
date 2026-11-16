import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Phase 2 step 1: team mode in S2b, team results, "Together" (plan.md §2.3, §4 S2b, decision 9).
struct TeamModeTests {

    private func doublesDraft(_ f: Fixture) -> MatchDraft {
        var draft = MatchDraft(sport: .badminton)
        draft.mode = .team
        draft.partners = [f.tom]
        draft.opponents = [f.lukas]
        draft.sets = [SetEntry(scoreA: 21, scoreB: 15), SetEntry(scoreA: 21, scoreB: 18)]
        return draft
    }

    @Test func teamSizesPerSport() {
        #expect(SportType.badminton.teamSizes == 2...2)
        #expect(SportType.basketball.teamSizes == 2...5)
        #expect(SportType.football.teamSizes == 2...11)
        #expect(SportType.boxing.teamSizes == nil)
        #expect(SportType.running.teamSizes == nil)
        #expect(!MatchDraft(sport: .boxing).allowsTeams)
        #expect(MatchDraft(sport: .padel).allowsTeams)
    }

    @Test func teamValidation() throws {
        let f = try Fixture()
        var draft = doublesDraft(f)
        #expect(draft.isValid)

        draft.opponents = []
        #expect(draft.validate() == .failure(.teamsUnequal))
        #expect(ResultIssue.teamsUnequal.message == "Both teams need the same number of players.")

        // Doubles are exactly 2 per team.
        draft.partners = [f.tom, f.max]
        draft.opponents = [f.lukas, f.max]
        #expect(draft.validate() == .failure(.teamSize(2...2)))
        #expect(ResultIssue.teamSize(2...2).message == "Each team needs 2 players.")
        #expect(ResultIssue.teamSize(2...5).message == "Each team needs 2–5 players.")

        // A 1v1 draft ignores leftover team members.
        draft.mode = .oneVsOne
        #expect(draft.isValid)
    }

    @Test func teamNamesAndPreview() throws {
        let f = try Fixture()
        var draft = doublesDraft(f)
        #expect(draft.names(friendName: "Max") == (a: "You & Tom", b: "Max & Lukas"))
        #expect(draft.previewText(friendName: "Max") == "You win 2–0")

        draft.sets = [SetEntry(scoreA: 15, scoreB: 21), SetEntry(scoreA: 18, scoreB: 21)]
        #expect(draft.previewText(friendName: "Max") == "Max & Lukas win 2–0")

        var big = MatchDraft(sport: .basketball)
        big.mode = .team
        big.partners = [f.tom, f.lukas]
        big.opponents = [Player(name: "Jonas Weber"), Player(name: "Sara Lind")]
        #expect(big.names(friendName: "Max") == (a: "Your team", b: "Max's team"))
        #expect(MatchDraft(sport: .badminton).names(friendName: "Max") == (a: "You", b: "Max"))
    }

    @Test func availablePlayers() throws {
        let f = try Fixture()
        var draft = MatchDraft(sport: .football)
        draft.mode = .team
        f.lukas.isArchived = true
        let available = draft.availablePlayers(from: [f.me, f.max, f.tom, f.lukas], friend: f.max)
        #expect(available.map(\.name) == ["Tom Berger"])   // not you, not Max, not archived

        draft.partners = [f.tom]
        #expect(draft.availablePlayers(from: [f.me, f.max, f.tom], friend: f.max).isEmpty)
    }

    @Test func savesTeamMatch() throws {
        let f = try Fixture()
        let match = doublesDraft(f).insertMatch(me: f.me, friend: f.max, into: f.context)
        #expect(match.mode == .team)
        #expect(match.participants.count == 4)
        #expect(match.teamFormat == "2v2")
        #expect(match.side(of: f.tom) == .a)
        #expect(match.side(of: f.lukas) == .b)

        // Team matches are not in the default record, but in "Team".
        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches) == Record())
        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches, filter: DuelFilter(mode: .team))
                == Record(wins: 1))
        #expect(Rivalry.record(of: f.me, against: f.lukas, in: f.matches, filter: DuelFilter(mode: .team))
                == Record(wins: 1))
        // Tom was my partner, not an opponent.
        #expect(Rivalry.record(of: f.me, against: f.tom, in: f.matches, filter: DuelFilter(mode: .all)) == Record())
    }

    @Test func detailTextShowsTeamFormat() throws {
        let f = try Fixture()
        var draft = doublesDraft(f)
        let nov12 = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 18)))
        draft.date = nov12
        let match = draft.insertMatch(me: f.me, friend: f.max, into: f.context)
        let now = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 16)))
        #expect(match.detailText(now: now) == "Nov 12 · 2v2 · Best of 3")
    }

    @Test func togetherRecord() throws {
        let f = try Fixture()
        // Me + Tom vs Max + Lukas, twice won, once lost.
        for won in [true, true, false] {
            var draft = doublesDraft(f)
            if !won { draft.sets = [SetEntry(scoreA: 10, scoreB: 21), SetEntry(scoreA: 10, scoreB: 21)] }
            draft.insertMatch(me: f.me, friend: f.max, into: f.context)
        }
        // A 1v1 against Tom doesn't count as "together".
        f.add(.badminton, .win, vs: [f.tom])

        #expect(Rivalry.togetherRecord(of: f.me, with: f.tom, in: f.matches) == Record(wins: 2, losses: 1))
        #expect(Rivalry.togetherRecord(of: f.me, with: f.max, in: f.matches) == Record())   // opponent
        #expect(Rivalry.togetherRecord(of: f.me, with: f.tom, in: f.matches,
                                       filter: DuelFilter(sport: .padel, mode: .team)) == Record())
    }

    @Test func editTeamMatchKeepsTeams() throws {
        let f = try Fixture()
        let match = doublesDraft(f).insertMatch(me: f.me, friend: f.max, into: f.context)

        var edited = MatchDraft(match: match, friend: f.max)
        #expect(edited.mode == .team)
        #expect(edited.teamsLocked)
        #expect(edited.partners.map(\.name) == ["Tom Berger"])
        #expect(edited.opponents.map(\.name) == ["Lukas Huber"])
        #expect(edited.isValid)

        edited.sets = [SetEntry(scoreA: 19, scoreB: 21), SetEntry(scoreA: 17, scoreB: 21)]
        edited.apply(to: match, context: f.context)
        #expect(match.participants.count == 4)
        #expect(match.outcome(for: f.me) == .loss)
        #expect(match.outcome(for: f.tom) == .loss)
        #expect(match.outcome(for: f.lukas) == .win)
    }
}
