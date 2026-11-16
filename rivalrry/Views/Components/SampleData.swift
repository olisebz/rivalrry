#if DEBUG
import Foundation
import SwiftData

/// Sample data for previews (design.md §9.4).
enum SampleData {

    /// In-memory container, optionally filled with the sample players and matches.
    static func container(filled: Bool = true) -> ModelContainer {
        let schema = Schema(AppSchema.models)
        let container = try! ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        if filled { insert(into: container.mainContext) }
        return container
    }

    static func insert(into context: ModelContext) {
        let me = Player(name: "Alex Morgan", colorHex: "6E6E73", isMe: true)
        let max = Player(name: "Max Keller", colorHex: "4F6BED")
        let tom = Player(name: "Tom Berger", colorHex: "E8590C")
        let lukas = Player(name: "Lukas Huber", colorHex: "7C3AED")
        let jonas = Player(name: "Jonas Weber", colorHex: "D6336C")
        for player in [me, max, tom, lukas, jonas] { context.insert(player) }

        // Newest match first; every series starts at the "last match" date and goes back in time.
        addSeries(in: context, me: me, friend: max, startingDaysAgo: 2, [
            (.badminton, 5, 3), (.pingPong, 4, 2), (.football, 2, 3), (.penaltyShootout, 1, 1),
        ])
        addSeries(in: context, me: me, friend: tom, startingDaysAgo: 1, [(.padel, 5, 7)])
        addSeries(in: context, me: me, friend: lukas, startingDaysAgo: 7, [(.pingPong, 3, 3)])
        addSeries(in: context, me: me, friend: jonas, startingDaysAgo: 22, [(.tennis, 8, 2)])
        addGoKartRace(in: context, players: [me, jonas], daysAgo: 21)
    }

    private static func addSeries(in context: ModelContext, me: Player, friend: Player, startingDaysAgo: Int,
                                  _ series: [(sport: SportType, wins: Int, losses: Int)]) {
        var daysAgo = startingDaysAgo
        for (sport, wins, losses) in series {
            let outcomes = Array(repeating: true, count: wins) + Array(repeating: false, count: losses)
            for won in outcomes {
                addMatch(in: context, sport: sport, iWin: won, me: me, friend: friend,
                         date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!)
                daysAgo += 2
            }
        }
    }

    /// A valid 1v1 match that `me` (side A) wins or loses.
    private static func addMatch(in context: ModelContext, sport: SportType, iWin: Bool,
                                 me: Player, friend: Player, date: Date) {
        let match = Match(sportType: sport, date: date, bestOf: sport.defaultBestOf, createdBy: me)
        context.insert(match)
        match.participants = [MatchParticipant(player: me, side: .a), MatchParticipant(player: friend, side: .b)]

        switch sport.scoringType {
        case .sets:
            let points = sport.setRules?.pointsToWin ?? 21
            let setsToWin = (match.bestOf ?? 3) / 2 + 1
            match.sets = (0..<setsToWin).map {
                SetScore(index: $0, scoreA: iWin ? points : points - 4, scoreB: iWin ? points - 4 : points)
            }
        case .points:
            match.sets = [SetScore(index: 0, scoreA: iWin ? 3 : 1, scoreB: iWin ? 1 : 3)]
        case .penalties:
            match.penalties = (0..<6).map { index in
                let side: Side = index.isMultiple(of: 2) ? .a : .b
                return PenaltyShot(index: index, side: side, scored: (side == .a) == iWin)
            }
        case .fight:
            match.fight = FightDetail(winnerSide: iWin ? .a : .b, method: .points)
        default:
            break
        }
    }

    private static func addGoKartRace(in context: ModelContext, players: [Player], daysAgo: Int) {
        let race = Match(sportType: .goKart, mode: .race,
                         date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
                         createdBy: players.first)
        context.insert(race)
        race.participants = players.enumerated().map { MatchParticipant(player: $1, place: $0 + 1) }
    }
}
#endif
