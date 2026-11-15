import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// In-memory store with the sample players from design.md §9.4.
final class Fixture {
    let container: ModelContainer
    let context: ModelContext
    let me = Player(name: "Alex Morgan", isMe: true)
    let max = Player(name: "Max Keller")
    let tom = Player(name: "Tom Berger")
    let lukas = Player(name: "Lukas Huber")
    private var nextDate = Date(timeIntervalSince1970: 1_700_000_000)

    init() throws {
        let schema = Schema(AppSchema.models)
        container = try ModelContainer(for: schema,
                                       configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        context = ModelContext(container)
        for player in [me, max, tom, lukas] { context.insert(player) }
    }

    var matches: [Match] { (try? context.fetch(FetchDescriptor<Match>())) ?? [] }

    /// Adds a valid match that ends with `outcome` for side A (= me, plus `partners`).
    @discardableResult
    func add(_ sport: SportType, _ outcome: DuelOutcome, vs opponents: [Player],
             partners: [Player] = [], status: MatchStatus = .local, date: Date? = nil) -> Match {
        let match = Match(sportType: sport, mode: partners.isEmpty && opponents.count == 1 ? .oneVsOne : .team,
                          date: date ?? advanceDate(), status: status, createdBy: me)
        context.insert(match)
        match.participants = ([me] + partners).map { MatchParticipant(player: $0, side: .a) }
            + opponents.map { MatchParticipant(player: $0, side: .b) }

        let (a, b) = outcome == .win ? (1, 0) : outcome == .loss ? (0, 1) : (0, 0)
        switch sport.scoringType {
        case .sets:
            let rules = sport.setRules!
            match.bestOf = sport.defaultBestOf
            let setsToWin = match.bestOf! / 2 + 1
            let won = SetScore(index: 0, scoreA: rules.pointsToWin, scoreB: 0)
            let lost = SetScore(index: 0, scoreA: 0, scoreB: rules.pointsToWin)
            match.sets = (0..<setsToWin).map { index in
                let template = outcome == .win ? won : lost
                return SetScore(index: index, scoreA: template.scoreA, scoreB: template.scoreB)
            }
        case .points:
            match.sets = [SetScore(index: 0, scoreA: a + 1, scoreB: b + 1)]
        case .penalties:
            // 3 rounds where only one side scores.
            match.penalties = (0..<6).map { index in
                let side: Side = index.isMultiple(of: 2) ? .a : .b
                return PenaltyShot(index: index, side: side, scored: (side == .a) == (outcome == .win))
            }
        case .fight:
            match.fight = FightDetail(winnerSide: outcome == .draw ? nil : (outcome == .win ? .a : .b),
                                      method: .points)
        default:
            break
        }
        return match
    }

    func advanceDate() -> Date {
        nextDate = nextDate.addingTimeInterval(86_400)
        return nextDate
    }

    /// Adds `wins` wins and `losses` losses in one sport.
    func add(_ sport: SportType, wins: Int, losses: Int, vs opponent: Player) {
        for _ in 0..<wins { add(sport, .win, vs: [opponent]) }
        for _ in 0..<losses { add(sport, .loss, vs: [opponent]) }
    }
}

struct MatchResultFromModelTests {

    @Test func setsResult() throws {
        let f = try Fixture()
        let match = f.add(.badminton, .win, vs: [f.max])
        #expect(match.result == MatchResult(outcome: .win(.a), scoreA: 2, scoreB: 0))
        match.bestOf = nil
        #expect(match.result == nil)
    }

    @Test func pointsResultIsStoredAsOneSetScore() throws {
        let f = try Fixture()
        let match = f.add(.football, .loss, vs: [f.max])
        #expect(match.result == MatchResult(outcome: .win(.b), scoreA: 1, scoreB: 2))
        match.sets = []
        #expect(match.result == nil)
    }

    @Test func penaltiesResult() throws {
        let f = try Fixture()
        let match = f.add(.penaltyShootout, .win, vs: [f.max])
        #expect(match.result == MatchResult(outcome: .win(.a), scoreA: 3, scoreB: 0))
    }

    @Test func fightResult() throws {
        let f = try Fixture()
        #expect(f.add(.boxing, .draw, vs: [f.max]).result == MatchResult(outcome: .draw))
        #expect(f.add(.boxing, .loss, vs: [f.max]).result == MatchResult(outcome: .win(.b)))
    }

    @Test func runningResult() throws {
        let f = try Fixture()
        let match = Match(sportType: .running, distanceMeters: 100)
        f.context.insert(match)
        let a = MatchParticipant(player: f.me, side: .a, timeMs: 12_340)
        let b = MatchParticipant(player: f.max, side: .b, timeMs: 12_900)
        match.participants = [a, b]
        #expect(match.result == MatchResult(outcome: .win(.a)))

        b.timeMs = 12_340
        #expect(match.result == MatchResult(outcome: .draw))

        a.dnf = true
        #expect(match.result == MatchResult(outcome: .win(.b)))

        b.dnf = true
        #expect(match.result == MatchResult(outcome: .draw))

        a.dnf = false
        b.dnf = false
        a.timeMs = nil
        #expect(match.result == nil)
    }
}

struct RivalryTests {

    @Test func sampleRecordAgainstMax() throws {
        let f = try Fixture()
        f.add(.badminton, wins: 5, losses: 3, vs: f.max)
        f.add(.pingPong, wins: 4, losses: 2, vs: f.max)
        f.add(.football, wins: 2, losses: 3, vs: f.max)
        f.add(.penaltyShootout, wins: 1, losses: 1, vs: f.max)

        let record = Rivalry.record(of: f.me, against: f.max, in: f.matches)
        #expect(record == Record(wins: 12, losses: 9, draws: 0))
        #expect(record.leader == .me)
        #expect(record.winRate == 12.0 / 21.0)

        let bySport = Rivalry.recordsBySport(of: f.me, against: f.max, in: f.matches)
        #expect(bySport.map(\.sport) == [.badminton, .pingPong, .football, .penaltyShootout])
        #expect(bySport.map(\.record) == [Record(wins: 5, losses: 3), Record(wins: 4, losses: 2),
                                          Record(wins: 2, losses: 3), Record(wins: 1, losses: 1)])
    }

    @Test func leaderAndTie() throws {
        let f = try Fixture()
        f.add(.padel, wins: 5, losses: 7, vs: f.tom)
        f.add(.pingPong, wins: 3, losses: 3, vs: f.lukas)
        #expect(Rivalry.record(of: f.me, against: f.tom, in: f.matches).leader == .friend)
        #expect(Rivalry.record(of: f.me, against: f.lukas, in: f.matches).leader == .tied)
        // Matches against others don't leak into a record.
        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches) == Record())
        #expect(Record().winRate == nil)
    }

    @Test func draws() throws {
        let f = try Fixture()
        f.add(.football, .draw, vs: [f.max])
        f.add(.football, .win, vs: [f.max])
        let record = Rivalry.record(of: f.me, against: f.max, in: f.matches)
        #expect(record == Record(wins: 1, losses: 0, draws: 1))
        #expect(record.matches == 2)
        #expect(record.winRate == 0.5)
    }

    @Test func onlyLocalAndConfirmedMatchesCount() throws {
        let f = try Fixture()
        f.add(.badminton, .win, vs: [f.max], status: .local)
        f.add(.badminton, .win, vs: [f.max], status: .confirmed)
        f.add(.badminton, .win, vs: [f.max], status: .pending)
        f.add(.badminton, .win, vs: [f.max], status: .rejected)
        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches) == Record(wins: 2))
    }

    @Test func invalidMatchesDontCount() throws {
        let f = try Fixture()
        let match = f.add(.badminton, .win, vs: [f.max])
        match.sets = [SetScore(index: 0, scoreA: 21, scoreB: 21)]
        #expect(match.duels(for: f.me).isEmpty)
    }

    @Test func teamMatchesAreSeparate() throws {
        let f = try Fixture()
        f.add(.badminton, .win, vs: [f.max])
        // Me + Tom beat Max + Lukas.
        f.add(.badminton, .win, vs: [f.max, f.lukas], partners: [f.tom])

        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches) == Record(wins: 1))

        let team = DuelFilter(mode: .team)
        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches, filter: team) == Record(wins: 1))
        #expect(Rivalry.record(of: f.me, against: f.lukas, in: f.matches, filter: team) == Record(wins: 1))
        // A partner is not an opponent.
        #expect(Rivalry.record(of: f.me, against: f.tom, in: f.matches, filter: team) == Record())

        let all = DuelFilter(mode: .all)
        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches, filter: all) == Record(wins: 2))
    }

    @Test func sportAndPeriodFilters() throws {
        let f = try Fixture()
        f.add(.badminton, .win, vs: [f.max])
        f.add(.pingPong, .loss, vs: [f.max])
        let cutoff = f.advanceDate()
        f.add(.badminton, .loss, vs: [f.max])

        let badminton = DuelFilter(sport: .badminton)
        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches, filter: badminton)
                == Record(wins: 1, losses: 1))

        let recent = DuelFilter(since: cutoff)
        #expect(Rivalry.record(of: f.me, against: f.max, in: f.matches, filter: recent) == Record(losses: 1))
    }

    @Test func duelsAreSortedByDate() throws {
        let f = try Fixture()
        let later = f.add(.badminton, .win, vs: [f.max])
        let earlier = f.add(.football, .loss, vs: [f.max], date: Date(timeIntervalSince1970: 0))
        let duels = Rivalry.duels(of: f.me, against: f.max, in: f.matches)
        #expect(duels.map(\.match.id) == [earlier.id, later.id])
    }

    @Test func duelsFromTheFriendsPointOfView() throws {
        let f = try Fixture()
        f.add(.badminton, wins: 2, losses: 1, vs: f.max)
        #expect(Rivalry.record(of: f.max, against: f.me, in: f.matches) == Record(wins: 1, losses: 2))
    }

    @Test func deletedOpponentStaysAsDuel() throws {
        let f = try Fixture()
        let match = f.add(.badminton, .win, vs: [f.max])
        try f.context.save()
        f.context.delete(f.max)
        try f.context.save()

        let duels = match.duels(for: f.me)
        #expect(duels.count == 1)
        #expect(duels.first?.opponent == nil)
    }

    @Test func lastMatch() throws {
        let f = try Fixture()
        f.add(.badminton, .win, vs: [f.max])
        let latest = f.add(.football, .loss, vs: [f.max])
        f.add(.padel, .win, vs: [f.max], status: .pending)
        f.add(.tennis, .win, vs: [f.tom])

        #expect(Rivalry.lastMatch(of: f.me, with: f.max, in: f.matches)?.id == latest.id)
        #expect(Rivalry.lastMatch(of: f.me, with: f.lukas, in: f.matches) == nil)
    }
}
