import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// S2b logic: entering, previewing and saving a match.
struct MatchDraftTests {

    @Test func defaultsPerSport() {
        #expect(MatchDraft(sport: .badminton).bestOf == 3)
        #expect(MatchDraft(sport: .pingPong).bestOf == 5)
        #expect(MatchDraft(sport: .penaltyShootout).penaltyShotsPerSide == 5)
        #expect(MatchDraft(sport: .boxing).fightRounds == 3)
        #expect(SportType.phase1Sports.contains(.running))
        #expect(!SportType.phase1Sports.contains(.goKart))
        #expect(!SportType.phase1Sports.contains(.custom))
    }

    @Test func badmintonPreviewFromMockup() {
        var draft = MatchDraft(sport: .badminton)
        draft.sets = [SetEntry(scoreA: 21, scoreB: 19), SetEntry(scoreA: 18, scoreB: 21), SetEntry(scoreA: 21, scoreB: 17)]
        #expect(draft.previewText(friendName: "Max") == "You win 2–1")
        #expect(!draft.canAddSet)

        draft.sets = [SetEntry(scoreA: 21, scoreB: 19), SetEntry(scoreA: 21, scoreB: 21)]
        #expect(draft.previewText(friendName: "Max") == nil)
        #expect(draft.validate() == .failure(.setScore(set: 2, sport: .badminton)))
        #expect(!draft.canAddSet)   // finish set 2 first
    }

    @Test func canAddSet() {
        var draft = MatchDraft(sport: .badminton)
        #expect(!draft.canAddSet)                       // 0:0 is open
        draft.sets = [SetEntry(scoreA: 21, scoreB: 10)]
        #expect(draft.canAddSet)
        draft.sets.append(SetEntry(scoreA: 10, scoreB: 21))
        #expect(draft.canAddSet)                        // 1:1 in Best of 3
        draft.isRetired = true
        #expect(!draft.canAddSet)
    }

    @Test func friendWinsAndDraw() {
        var football = MatchDraft(sport: .football)
        football.scoreA = 4
        football.scoreB = 5
        #expect(football.previewText(friendName: "Max") == "Max wins 5–4")
        football.scoreA = 5
        #expect(football.previewText(friendName: "Max") == "Draw")

        var basketball = MatchDraft(sport: .basketball)
        #expect(basketball.validate() == .failure(.drawNotAllowed(.basketball)))
        basketball.scoreA = 21
        #expect(basketball.previewText(friendName: "Max") == "You win 21–0")
    }

    @Test func tiebreakField() {
        let draft = MatchDraft(sport: .tennis)
        #expect(draft.needsTiebreakField(SetEntry(scoreA: 7, scoreB: 6)))
        #expect(draft.needsTiebreakField(SetEntry(scoreA: 6, scoreB: 7)))
        #expect(!draft.needsTiebreakField(SetEntry(scoreA: 7, scoreB: 5)))
        #expect(!MatchDraft(sport: .badminton).needsTiebreakField(SetEntry(scoreA: 22, scoreB: 21)))
    }

    @Test func penaltyTapping() {
        var draft = MatchDraft(sport: .penaltyShootout)
        #expect(draft.shotState(round: 0, side: .a) == .next)
        #expect(draft.shotState(round: 0, side: .b) == .empty)

        draft.tapShot(round: 0, side: .a)          // goal
        #expect(draft.shotState(round: 0, side: .a) == .scored)
        #expect(draft.shotState(round: 0, side: .b) == .next)
        draft.tapShot(round: 0, side: .a)          // goal → miss
        #expect(draft.shotState(round: 0, side: .a) == .missed)
        draft.tapShot(round: 0, side: .a)          // last miss → removed
        #expect(draft.penaltyShots.isEmpty)

        draft.tapShot(round: 2, side: .a)          // not the next shot: ignored
        #expect(draft.penaltyShots.isEmpty)
    }

    @Test func penaltySuddenDeathRoundsAppear() {
        var draft = MatchDraft(sport: .penaltyShootout)
        draft.penaltyShotsPerSide = 3
        draft.penaltyShots = [true, true, false, false, true, true]   // 2:2 after 3 rounds
        #expect(draft.penaltyRounds == 4)
        #expect(draft.shotState(round: 3, side: .a) == .next)

        draft.penaltyShots += [true, false]                           // A wins in sudden death
        #expect(draft.previewText(friendName: "Max") == "You win 3–2")
        #expect(draft.penaltyRounds == 4)
        #expect(draft.shotState(round: 4, side: .a) == .empty)
    }

    @Test func fightEntry() {
        var draft = MatchDraft(sport: .boxing)
        #expect(draft.previewText(friendName: "Max") == "You win")
        draft.fightWinner = nil
        #expect(draft.previewText(friendName: "Max") == "Draw")
        draft.fightMethod = .ko
        #expect(draft.validate() == .failure(.drawOnlyByPoints))
        draft.fightWinner = .b
        draft.fightEndRound = 5    // clamped to 3 rounds
        #expect(draft.fightEntry.endRound == 3)
        #expect(draft.previewText(friendName: "Max") == "Max wins")
    }

    @Test func runningEntry() {
        var draft = MatchDraft(sport: .running)
        #expect(draft.validate() == .failure(.missingTime))
        draft.timeTextA = "12.34"
        draft.timeTextB = "12,90"
        #expect(draft.previewText(friendName: "Max") == "You win")
        draft.dnfA = true
        #expect(draft.previewText(friendName: "Max") == "Max wins")
        draft.distanceMeters = nil
        #expect(draft.validate() == .failure(.invalidDistance))
    }

    @Test func timeParsing() {
        #expect(TimeText.milliseconds(from: "12.34") == 12_340)
        #expect(TimeText.milliseconds(from: "4:05.2") == 245_200)
        #expect(TimeText.milliseconds(from: "1:02:03.40") == 3_723_400)
        #expect(TimeText.milliseconds(from: "9,05") == 9_050)
        #expect(TimeText.milliseconds(from: "") == nil)
        #expect(TimeText.milliseconds(from: "4:75") == nil)
        #expect(TimeText.milliseconds(from: "abc") == nil)
        #expect(TimeText.distance(1_000) == "1 km")
        #expect(TimeText.distance(400) == "400 m")
    }

    // MARK: - Saving

    @Test func savesSetsMatch() throws {
        let f = try Fixture()
        var draft = MatchDraft(sport: .tennis)
        draft.sets = [SetEntry(scoreA: 6, scoreB: 4), SetEntry(scoreA: 7, scoreB: 6, tiebreakA: 7, tiebreakB: 5)]
        draft.note = "Windy"
        let match = draft.insertMatch(me: f.me, friend: f.max, into: f.context)

        #expect(match.status == .local)
        #expect(match.bestOf == 3)
        #expect(match.note == "Windy")
        #expect(match.orderedSets.last?.tiebreakA == 7)
        #expect(match.result == MatchResult(outcome: .win(.a), scoreA: 2, scoreB: 0))
        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches) == Record(wins: 1))
    }

    @Test func savesRetirement() throws {
        let f = try Fixture()
        var draft = MatchDraft(sport: .badminton)
        draft.sets = [SetEntry(scoreA: 12, scoreB: 8)]
        draft.isRetired = true
        draft.retiredSide = .b
        let match = draft.insertMatch(me: f.me, friend: f.max, into: f.context)
        #expect(match.retiredSide == .b)
        #expect(match.outcome(for: f.me) == .win)
    }

    @Test func savesPointsAndPenalties() throws {
        let f = try Fixture()
        var football = MatchDraft(sport: .football)
        football.scoreA = 4
        football.scoreB = 5
        #expect(football.insertMatch(me: f.me, friend: f.max, into: f.context).scoreText(for: f.me) == "4 – 5")

        var penalties = MatchDraft(sport: .penaltyShootout)
        penalties.penaltyShotsPerSide = 3
        penalties.penaltyShots = [true, true, false, false, true, true, true, false]
        let match = penalties.insertMatch(me: f.me, friend: f.max, into: f.context)
        #expect(match.penaltyShotsPerSide == 3)
        #expect(match.orderedPenalties.filter(\.isSuddenDeath).count == 2)
        #expect(match.result == MatchResult(outcome: .win(.a), scoreA: 3, scoreB: 2))
    }

    @Test func savesFightAndRunning() throws {
        let f = try Fixture()
        var fight = MatchDraft(sport: .boxing)
        fight.fightWinner = .b
        fight.fightMethod = .tko
        fight.fightEndRound = 2
        let bout = fight.insertMatch(me: f.me, friend: f.max, into: f.context)
        #expect(bout.fight?.endRound == 2)
        #expect(bout.scoreText(for: f.me) == "TKO")
        #expect(bout.outcome(for: f.me) == .loss)

        var run = MatchDraft(sport: .running)
        run.distanceMeters = 400
        run.timeTextA = "58.1"
        run.dnfB = true
        run.timeTextB = "61.0"   // ignored because of DNF
        let race = run.insertMatch(me: f.me, friend: f.max, into: f.context)
        #expect(race.distanceMeters == 400)
        #expect(race.participants(on: .b).first?.timeMs == nil)
        #expect(race.scoreText(for: f.me) == "58.10 – DNF")
    }

    @Test func noteIsLimited() throws {
        let f = try Fixture()
        var draft = MatchDraft(sport: .football)
        draft.note = String(repeating: "a", count: 250)
        let match = draft.insertMatch(me: f.me, friend: f.max, into: f.context)
        #expect(match.note?.count == 200)
    }
}
