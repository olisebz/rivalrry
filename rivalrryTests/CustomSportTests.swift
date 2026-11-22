import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Phase 2 step 7: custom sports (plan.md §2.2 "Custom sport", §4 S9).
struct CustomSportTests {

    private func custom(_ f: Fixture, _ name: String, _ scoring: ScoringType,
                        draws: Bool = false, teams: Bool = false,
                        pointsPerSet: Int? = nil, winBy: Int? = nil) -> CustomSport {
        let sport = CustomSport(name: name, scoringType: scoring, allowsDraw: draws, allowsTeams: teams,
                                pointsPerSet: pointsPerSet, winBy: winBy)
        f.context.insert(sport)
        return sport
    }

    @discardableResult
    private func save(_ f: Fixture, _ draft: MatchDraft, vs friend: Player? = nil) -> Match {
        var draft = draft
        draft.date = f.advanceDate()
        return draft.insertMatch(me: f.me, friend: friend ?? f.max, into: f.context)
    }

    // MARK: - Identity

    @Test func everyCustomSportIsItsOwnSport() throws {
        let f = try Fixture()
        let darts = custom(f, "Darts", .winLoss)
        let bowling = custom(f, "Bowling", .points)
        #expect(Sport(darts) != Sport(bowling))
        #expect(Sport(darts) == Sport(darts))
        #expect(Sport(.badminton) == .badminton)
        #expect(Sport(darts).id == "custom.\(darts.id.uuidString)")
        #expect(Sport(darts).storedType == .custom)
        #expect(Sport(darts).displayName == "Darts")

        var a = MatchDraft(sport: Sport(darts))
        a.winner = .a
        save(f, a)
        var b = MatchDraft(sport: Sport(bowling))
        b.scoreA = 180
        b.scoreB = 150
        save(f, b)
        save(f, b)

        let sports = Rivalry.sportsPlayed(of: f.me, with: f.max, in: f.matches)
        #expect(sports == [Sport(bowling), Sport(darts)])
        let bySport = Rivalry.recordsBySport(of: f.me, against: f.max, in: f.matches)
        #expect(bySport.map(\.record.wins) == [2, 1])

        let elo = Elo.table(for: f.matches)
        #expect(elo.history(of: f.me, sport: Sport(darts), group: .singles).count == 1)
        #expect(elo.history(of: f.me, sport: Sport(bowling), group: .singles).count == 2)
    }

    // MARK: - Scoring types

    @Test func winLoss() throws {
        let f = try Fixture()
        let darts = custom(f, "Darts", .winLoss)
        var draft = MatchDraft(sport: Sport(darts))
        #expect(draft.previewText(friendName: "Max") == "You win")

        draft.winner = nil
        #expect(draft.validate() == .failure(.drawNotAllowed(Sport(darts))))
        #expect(ResultIssue.drawNotAllowed(Sport(darts)).message == "Darts can't end in a tie")

        draft.winner = .b
        let match = save(f, draft)
        #expect(match.customSport?.id == darts.id)
        #expect(match.outcome(for: f.me) == .loss)
        #expect(match.scoreText(for: f.me) == "Loss")
        #expect(match.scoreText(for: f.max) == "Win")
        // Editing loads the winner again.
        #expect(MatchDraft(match: match).winner == .b)
    }

    @Test func winLossWithDraws() throws {
        let f = try Fixture()
        let chess = custom(f, "Chess", .winLoss, draws: true)
        var draft = MatchDraft(sport: Sport(chess))
        draft.winner = nil
        #expect(draft.previewText(friendName: "Max") == "Draw")
        let match = save(f, draft)
        #expect(match.scoreText(for: f.me) == "Draw")
        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches) == Record(draws: 1))
    }

    @Test func customSetRules() throws {
        let f = try Fixture()
        let squash = custom(f, "Squash", .sets, pointsPerSet: 15, winBy: 2)
        let sport = Sport(squash)
        let rules = try #require(sport.setRules)
        #expect(ResultRules.check(SetEntry(scoreA: 15, scoreB: 13), rules: rules) == .won(.a))
        #expect(ResultRules.check(SetEntry(scoreA: 15, scoreB: 14), rules: rules) == .unfinished)
        #expect(ResultRules.check(SetEntry(scoreA: 19, scoreB: 17), rules: rules) == .won(.a))
        #expect(sport.bestOfOptions == [1, 3, 5])
        #expect(sport.defaultBestOf == 3)
        #expect(SportSettings.defaultBestOf(for: sport) == 3)

        var draft = MatchDraft(sport: sport)
        draft.sets = [SetEntry(scoreA: 15, scoreB: 10), SetEntry(scoreA: 16, scoreB: 14)]
        #expect(draft.previewText(friendName: "Max") == "You win 2–0")
        let match = save(f, draft)
        #expect(match.result?.outcome == .win(.a))
        #expect(Rivalry.margins(Rivalry.duels(of: f.me, against: f.max, in: f.matches), me: f.me).map(\.margin) == [7])
    }

    @Test func customPointsAndTeams() throws {
        let f = try Fixture()
        let bowling = custom(f, "Bowling", .points, draws: true, teams: true)
        let sport = Sport(bowling)
        #expect(sport.teamSizes == 2...11)
        #expect(sport.allowsDraw)

        var draft = MatchDraft(sport: sport)
        draft.mode = .team
        draft.partners = [f.tom]
        draft.opponents = [f.lukas]
        draft.scoreA = 300
        draft.scoreB = 280
        #expect(draft.isValid)
        let match = save(f, draft)
        #expect(match.mode == .team)
        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches, filter: DuelFilter(mode: .team)) == Record(wins: 1))

        // No team mode for races, even if it was set.
        let race = custom(f, "Kart", .placement, teams: true)
        #expect(Sport(race).teamSizes == nil)
    }

    @Test func customTimeHasNoDistance() throws {
        let f = try Fixture()
        let swim = custom(f, "Swimming", .time)
        let sport = Sport(swim)
        #expect(!sport.usesDistance)

        var draft = MatchDraft(sport: sport)
        #expect(draft.distanceMeters == nil)
        draft.timeTextA = "1:02.50"
        draft.timeTextB = "1:03.10"
        #expect(draft.isValid)
        let match = save(f, draft)
        #expect(match.distanceMeters == nil)
        #expect(match.outcome(for: f.me) == .win)

        let rows = SportComparison.rows(for: sport, duels: Rivalry.duels(of: f.me, against: f.max, in: f.matches), me: f.me)
        #expect(rows.contains { $0.title == "Best time" && $0.mine == "1:02.50" })
    }

    @Test func customPlacementIsARace() throws {
        let f = try Fixture()
        let mario = custom(f, "Mario Kart", .placement)
        let sport = Sport(mario)
        #expect(!sport.usesLaps)

        var draft = MatchDraft(sport: sport)
        draft.setUpRace(me: f.me, friend: f.max)
        draft.racers.insert(RaceEntry(player: f.tom), at: 0)
        #expect(draft.isRace)
        let race = save(f, draft)
        #expect(race.mode == .race)
        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches) == Record(wins: 1))
        #expect(Rivalry.record(of: f.me, against: f.tom, in: f.matches) == Record(losses: 1))
    }

    // MARK: - Form

    @Test func formValidation() throws {
        var form = CustomSportForm()
        #expect(form.issue(otherNames: []) == "Enter a name.")
        form.name = "  Darts "
        #expect(form.issue(otherNames: []) == nil)
        #expect(form.issue(otherNames: ["darts"]) == "You already have a sport called Darts.")
        form.name = "badminton"
        #expect(form.issue(otherNames: []) == "You already have a sport called badminton.")

        form.name = "Squash"
        form.scoringType = .sets
        form.pointsPerSet = 0
        #expect(form.issue(otherNames: []) == "Choose the points per set and the lead.")
    }

    @Test func formOnlyKeepsOptionsThatApply() throws {
        var form = CustomSportForm()
        form.name = "Kart"
        form.scoringType = .placement
        form.allowsDraw = true
        form.allowsTeams = true
        #expect(!form.showsDraws && !form.showsTeams)
        let sport = form.makeSport()
        #expect(sport.name == "Kart")
        #expect(!sport.allowsDraw && !sport.allowsTeams)
        #expect(sport.pointsPerSet == nil)

        // Locked scoring: the type stays, name and symbol change.
        var edit = CustomSportForm(sport: sport)
        edit.name = "Kart Night"
        edit.symbolName = "gamecontroller"
        edit.scoringType = .points
        edit.apply(to: sport, canChangeScoring: false)
        #expect(sport.name == "Kart Night")
        #expect(sport.symbolName == "gamecontroller")
        #expect(sport.scoringType == .placement)
    }

    @Test func deleteSportDeletesItsMatches() throws {
        let f = try Fixture()
        let darts = custom(f, "Darts", .winLoss)
        save(f, MatchDraft(sport: Sport(darts)))
        save(f, MatchDraft(sport: Sport(darts)))
        f.add(.badminton, .win, vs: [f.max])
        #expect(CustomSports.matches(of: darts, in: f.matches).count == 2)
        #expect(CustomSports.deleteWarning(matchCount: 2) == "Deletes 2 matches. This can't be undone.")
        #expect(CustomSports.deleteWarning(matchCount: 1) == "Deletes 1 match. This can't be undone.")

        try CustomSports.delete(darts, in: f.context)
        #expect(f.matches.count == 1)
        #expect(f.matches.first?.sportType == .badminton)
        #expect(((try? f.context.fetch(FetchDescriptor<CustomSport>())) ?? []).isEmpty)
    }

    // MARK: - Grid & settings

    @Test func entrySportsWithCustomSports() throws {
        let f = try Fixture()
        let darts = custom(f, "Darts", .winLoss)
        let chess = custom(f, "Chess", .winLoss)
        let sports = SportSettings.entrySports(favorites: [], hidden: [], custom: [darts, chess])
        #expect(Array(sports.suffix(2)) == [Sport(chess), Sport(darts)])
        #expect(sports.count == SportType.phase1Sports.count + 2)

        let hidden = SportSettings.entrySports(favorites: [], hidden: [], custom: [darts, chess],
                                               hiddenCustom: [darts.id])
        #expect(!hidden.contains(Sport(darts)))
        #expect(SportSettings.decodeIDs(SportSettings.encodeIDs([darts.id])) == [darts.id])
    }

    @Test func profileFavoriteCanBeCustom() throws {
        let f = try Fixture()
        let darts = custom(f, "Darts", .winLoss)
        save(f, MatchDraft(sport: Sport(darts)))
        save(f, MatchDraft(sport: Sport(darts)))
        f.add(.badminton, .win, vs: [f.max])
        #expect(Rivalry.profileStats(of: f.me, in: f.matches).favoriteSport == Sport(darts))
    }
}
