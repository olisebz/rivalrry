import Foundation

/// S2c filter "Period" (plan.md §4 S2c).
enum StatsPeriod: String, CaseIterable, Identifiable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case oneYear = "1Y"
    case all = "All"

    var id: String { rawValue }

    /// Start of the period, `nil` for "All".
    func since(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .oneMonth: calendar.date(byAdding: .month, value: -1, to: now)
        case .threeMonths: calendar.date(byAdding: .month, value: -3, to: now)
        case .oneYear: calendar.date(byAdding: .year, value: -1, to: now)
        case .all: nil
        }
    }
}

extension ModeFilter {
    /// Texts of the S2c filter "Mode".
    var title: String {
        switch self {
        case .singles: "1v1 & Race"
        case .team: "Team"
        case .all: "All"
        }
    }
}

/// Cumulative wins after each duel ("Record over Time").
struct CumulativePoint: Equatable {
    let date: Date
    let myWins: Int
    let theirWins: Int
}

/// Wins, losses and draws as shares for the "Win Rate" donut.
struct OutcomeShare: Equatable {
    let outcome: DuelOutcome
    let count: Int
}

extension Rivalry {

    /// Running win totals of both players, one point per duel, oldest first.
    static func cumulativeWins(_ duels: [Duel]) -> [CumulativePoint] {
        var mine = 0, theirs = 0
        return duels.sorted { $0.date < $1.date }.map { duel in
            switch duel.outcome {
            case .win: mine += 1
            case .loss: theirs += 1
            case .draw: break
            }
            return CumulativePoint(date: duel.date, myWins: mine, theirWins: theirs)
        }
    }

    /// The last point on or before `date`, for the chart selection.
    static func point(at date: Date, in points: [CumulativePoint]) -> CumulativePoint? {
        points.last { $0.date <= date } ?? points.first
    }

    /// Donut slices without empty ones.
    static func outcomeShares(_ record: Record) -> [OutcomeShare] {
        [OutcomeShare(outcome: .win, count: record.wins),
         OutcomeShare(outcome: .loss, count: record.losses),
         OutcomeShare(outcome: .draw, count: record.draws)]
            .filter { $0.count > 0 }
    }

    /// "57 %" – win rate rounded to whole percent, "–" without duels.
    static func percentText(_ rate: Double?) -> String {
        guard let rate else { return "–" }
        return "\(Int((rate * 100).rounded())) %"
    }
}
