import Foundation
import Testing
@testable import rivalrry

/// S2c "Head to Head" per sport (decision 8).
struct SportComparisonTests {

    private func rows(_ f: Fixture, _ sport: SportType, filter: DuelFilter = DuelFilter()) -> [String: ComparisonRow] {
        let duels = Rivalry.duels(of: f.me, against: f.max, in: f.matches, filter: filter)
        let rows = SportComparison.rows(for: sport, duels: duels, me: f.me)
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.title, $0) })
    }

    private func save(_ f: Fixture, _ draft: MatchDraft) {
        draft.insertMatch(me: f.me, friend: f.max, into: f.context)
    }

    @Test func badminton() throws {
        let f = try Fixture()
        var win = MatchDraft(sport: .badminton)
        win.sets = [SetEntry(scoreA: 21, scoreB: 19), SetEntry(scoreA: 18, scoreB: 21), SetEntry(scoreA: 22, scoreB: 20)]
        save(f, win)
        var loss = MatchDraft(sport: .badminton)
        loss.sets = [SetEntry(scoreA: 15, scoreB: 21), SetEntry(scoreA: 10, scoreB: 21)]
        save(f, loss)

        let r = rows(f, .badminton)
        #expect(r["Wins"] == ComparisonRow(title: "Wins", mine: "1", theirs: "1", leader: .tied))
        #expect(r["Sets won"] == ComparisonRow(title: "Sets won", mine: "2", theirs: "3", leader: .friend))
        // 21+18+22+15+10 = 86 vs 19+21+20+21+21 = 102
        #expect(r["Points won"] == ComparisonRow(title: "Points won", mine: "86", theirs: "102", leader: .friend))
        #expect(r["Avg. points per set"]?.mine == "17.2")
        #expect(r["Set win rate"] == ComparisonRow(title: "Set win rate", mine: "40 %", theirs: "60 %", leader: .friend))
        #expect(r["Deuce sets won"] == ComparisonRow(title: "Deuce sets won", mine: "1", theirs: "0", leader: .me))
    }

    @Test func tennisCountsGamesAndTiebreaks() throws {
        let f = try Fixture()
        var draft = MatchDraft(sport: .tennis)
        draft.sets = [SetEntry(scoreA: 7, scoreB: 6, tiebreakA: 7, tiebreakB: 4), SetEntry(scoreA: 6, scoreB: 3)]
        save(f, draft)

        let r = rows(f, .tennis)
        #expect(r["Games won"] == ComparisonRow(title: "Games won", mine: "13", theirs: "9", leader: .me))
        #expect(r["Tiebreaks won"]?.mine == "1")
        #expect(r["Avg. games per set"]?.mine == "6.5")
        #expect(r["Points won"] == nil)
    }

    @Test func football() throws {
        let f = try Fixture()
        for (a, b) in [(5, 1), (2, 3), (1, 1), (0, 4)] {
            var draft = MatchDraft(sport: .football)
            draft.scoreA = a
            draft.scoreB = b
            save(f, draft)
        }
        let r = rows(f, .football)
        #expect(r["Wins"] == ComparisonRow(title: "Wins", mine: "1", theirs: "2", leader: .friend))
        #expect(r["Draws"] == ComparisonRow(title: "Draws", mine: "1", theirs: "1", leader: nil))
        #expect(r["Goals"] == ComparisonRow(title: "Goals", mine: "8", theirs: "9", leader: .friend))
        #expect(r["Avg. goals per match"]?.mine == "2.0")
        #expect(r["Biggest win"] == ComparisonRow(title: "Biggest win", mine: "5–1", theirs: "4–0", leader: .tied))
    }

    @Test func basketballHasNoDrawsRow() throws {
        let f = try Fixture()
        var draft = MatchDraft(sport: .basketball)
        draft.scoreA = 21
        draft.scoreB = 15
        save(f, draft)
        let r = rows(f, .basketball)
        #expect(r["Draws"] == nil)
        #expect(r["Points"]?.mine == "21")
    }

    @Test func penalties() throws {
        let f = try Fixture()
        var regular = MatchDraft(sport: .penaltyShootout)
        regular.penaltyShotsPerSide = 3
        regular.penaltyShots = [true, false, true, false]            // 2:0 after 2 rounds, decided
        save(f, regular)
        var suddenDeath = MatchDraft(sport: .penaltyShootout)
        suddenDeath.penaltyShotsPerSide = 3
        suddenDeath.penaltyShots = [true, true, false, false, true, true, false, true]  // Max wins in sudden death
        save(f, suddenDeath)

        let r = rows(f, .penaltyShootout)
        // You: 2 + 2 goals, Max: 0 + 3 goals, both from 6 shots.
        #expect(r["Goals"] == ComparisonRow(title: "Goals", mine: "4", theirs: "3", leader: .me))
        #expect(r["Conversion rate"] == ComparisonRow(title: "Conversion rate", mine: "67 %", theirs: "50 %", leader: .me))
        #expect(r["Sudden death wins"] == ComparisonRow(title: "Sudden death wins", mine: "0", theirs: "1", leader: .friend))
    }

    @Test func boxing() throws {
        let f = try Fixture()
        var ko = MatchDraft(sport: .boxing)
        ko.fightMethod = .ko
        ko.fightEndRound = 2
        save(f, ko)
        var points = MatchDraft(sport: .boxing)
        points.fightWinner = .b
        save(f, points)
        var draw = MatchDraft(sport: .boxing)
        draw.fightWinner = nil
        save(f, draw)

        let r = rows(f, .boxing)
        #expect(r["Wins by KO/TKO"] == ComparisonRow(title: "Wins by KO/TKO", mine: "1", theirs: "0", leader: .me))
        #expect(r["Wins by points"] == ComparisonRow(title: "Wins by points", mine: "0", theirs: "1", leader: .friend))
        #expect(r["Draws"]?.mine == "1")
    }

    @Test func runningBestTimes() throws {
        let f = try Fixture()
        for (a, b) in [("12.40", "12.90"), ("12.10", "12.50")] {
            var draft = MatchDraft(sport: .running)
            draft.timeTextA = a
            draft.timeTextB = b
            save(f, draft)
        }
        var long = MatchDraft(sport: .running)
        long.distanceMeters = 400
        long.timeTextB = "60.0"
        long.dnfA = true
        save(f, long)

        let r = rows(f, .running)
        // Lower time is better.
        #expect(r["Best 100 m"] == ComparisonRow(title: "Best 100 m", mine: "12.10", theirs: "12.50", leader: .me))
        #expect(r["Best 400 m"] == ComparisonRow(title: "Best 400 m", mine: "–", theirs: "1:00.00", leader: .friend))
        #expect(r["Wins"]?.theirs == "1")
    }

    @Test func respectsFiltersAndOtherSports() throws {
        let f = try Fixture()
        f.add(.badminton, .win, vs: [f.max], date: Date().addingTimeInterval(-60 * 86_400))
        f.add(.badminton, .loss, vs: [f.max], date: Date().addingTimeInterval(-3 * 86_400))
        f.add(.pingPong, .win, vs: [f.max], date: Date().addingTimeInterval(-2 * 86_400))

        let lastMonth = DuelFilter(sport: .badminton, since: StatsPeriod.oneMonth.since())
        #expect(rows(f, .badminton, filter: lastMonth)["Wins"]?.mine == "0")
        #expect(rows(f, .badminton)["Wins"]?.mine == "1")
        #expect(rows(f, .boxing).isEmpty)
    }
}
