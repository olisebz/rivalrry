import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// plan.md Phase 2 "Done when": a padel doubles match and a go-kart race with 4 people
/// show up correctly in record and Elo.
struct PhaseTwoDoneTests {

    @Test func padelDoublesAndGoKartRace() throws {
        let f = try Fixture()

        // Padel 2v2: you & Tom beat Max & Lukas 6–3, 6–4.
        var padel = MatchDraft(sport: .padel)
        padel.mode = .team
        padel.partners = [f.tom]
        padel.opponents = [f.lukas]
        padel.sets = [SetEntry(scoreA: 6, scoreB: 3), SetEntry(scoreA: 6, scoreB: 4)]
        padel.date = f.advanceDate()
        #expect(padel.isValid)
        padel.insertMatch(me: f.me, friend: f.max, into: f.context)

        // Go-Kart with 4: Max 1st, you 2nd, Tom 3rd, Lukas 4th (plan.md §2.3).
        var kart = MatchDraft(sport: .goKart)
        kart.racers = [f.max, f.me, f.tom, f.lukas].map { RaceEntry(player: $0) }
        kart.date = f.advanceDate()
        #expect(kart.isValid)
        kart.insertMatch(me: f.me, friend: f.max, into: f.context)

        let matches = f.matches
        let team = DuelFilter(mode: .team)

        // Record: the race counts in the default record, the doubles match only under "Team".
        #expect(Rivalry.record(of: f.me, against: f.max, in: matches) == Record(losses: 1))
        #expect(Rivalry.record(of: f.me, against: f.tom, in: matches) == Record(wins: 1))
        #expect(Rivalry.record(of: f.me, against: f.lukas, in: matches) == Record(wins: 1))
        #expect(Rivalry.record(of: f.me, against: f.max, in: matches, filter: team) == Record(wins: 1))
        #expect(Rivalry.record(of: f.me, against: f.lukas, in: matches, filter: team) == Record(wins: 1))
        // Tom was your partner: not an opponent, but "Together".
        #expect(Rivalry.record(of: f.me, against: f.tom, in: matches, filter: team) == Record())
        #expect(Rivalry.togetherRecord(of: f.me, with: f.tom, in: matches, filter: team) == Record(wins: 1))

        // Elo: Padel Team and Go-Kart Singles are separate ratings.
        let elo = Elo.table(for: matches)
        func rating(_ player: Player, _ sport: Sport, _ group: EloGroup) -> Double? {
            elo.history(of: player, sport: sport, group: group).last?.rating
        }
        // Team: both averages 1000 → ±20 for everyone on a team.
        #expect(rating(f.me, .padel, .team) == 1020)
        #expect(rating(f.tom, .padel, .team) == 1020)
        #expect(rating(f.max, .padel, .team) == 980)
        #expect(rating(f.lukas, .padel, .team) == 980)
        // Race: K/3 per duel → +20, +6.67, −6.67, −20.
        #expect(abs(rating(f.max, .goKart, .singles)! - 1020) < 0.001)
        #expect(abs(rating(f.me, .goKart, .singles)! - (1000 + 20.0 / 3)) < 0.001)
        #expect(abs(rating(f.tom, .goKart, .singles)! - (1000 - 20.0 / 3)) < 0.001)
        #expect(abs(rating(f.lukas, .goKart, .singles)! - 980) < 0.001)
        // No Padel Singles or Go-Kart Team rating was created.
        #expect(rating(f.me, .padel, .singles) == nil)
        #expect(rating(f.me, .goKart, .team) == nil)
        // One match each: still "Unranked" (from 3 matches).
        #expect(elo.rating(of: f.me, sport: .padel, group: .team) == nil)
    }
}
