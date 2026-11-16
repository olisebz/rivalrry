import Foundation

/// Built-in sports. Fixed in code, not stored in the database (plan.md §5).
/// Custom sports are stored as `CustomSport`; `.custom` marks a match that uses one.
enum SportType: String, Codable, CaseIterable, Identifiable {
    case badminton, padel, tennis, pingPong, football,
         basketball, penaltyShootout, boxing, goKart, running, custom

    var id: String { rawValue }

    /// Built-in sports that can be logged: all duel sports (Phase 1) plus Go-Kart races (Phase 2).
    static let phase1Sports: [SportType] = [
        .badminton, .padel, .tennis, .pingPong, .football,
        .basketball, .penaltyShootout, .boxing, .goKart, .running,
    ]
}

enum SportCategory: String, Codable, CaseIterable {
    case racket, ball, combat, race, custom
}

enum ScoringType: String, Codable, CaseIterable {
    case sets, points, penalties, fight, placement, time, winLoss
}

enum MatchMode: String, Codable, CaseIterable {
    case oneVsOne, team, race
}

/// Rules for winning a single set (plan.md §2.2).
struct SetRules: Equatable {
    /// Points (or games) needed to win a set.
    let pointsToWin: Int
    /// Required lead to win a set.
    let winBy: Int
    /// Hard cap where the next point wins regardless of lead (Badminton: 30).
    let maxPoints: Int?
    /// Tiebreak played at `pointsToWin`:`pointsToWin` (Tennis/Padel at 6:6 → 7:6).
    let tiebreak: TiebreakRules?
}

struct TiebreakRules: Equatable {
    let pointsToWin: Int
    let winBy: Int
}

extension SportType {
    var displayName: String {
        switch self {
        case .badminton: "Badminton"
        case .padel: "Padel"
        case .tennis: "Tennis"
        case .pingPong: "Ping Pong"
        case .football: "Football"
        case .basketball: "Basketball"
        case .penaltyShootout: "Penalty Shootout"
        case .boxing: "Boxing"
        case .goKart: "Go-Kart"
        case .running: "Running"
        case .custom: "Custom"
        }
    }

    /// SF Symbol name (design.md §5). Replaces the emoji from plan.md.
    var symbolName: String {
        switch self {
        case .badminton: "figure.badminton"
        case .padel: "figure.racquetball"
        case .tennis: "figure.tennis"
        case .pingPong: "figure.table.tennis"
        case .football: "figure.soccer"
        case .basketball: "figure.basketball"
        case .penaltyShootout: "soccerball"
        case .boxing: "figure.boxing"
        case .goKart: "steeringwheel"
        case .running: "figure.run"
        case .custom: "plus"
        }
    }

    var category: SportCategory {
        switch self {
        case .badminton, .padel, .tennis, .pingPong: .racket
        case .football, .basketball, .penaltyShootout: .ball
        case .boxing: .combat
        case .goKart, .running: .race
        case .custom: .custom
        }
    }

    /// For `.custom` the actual scoring type comes from the `CustomSport`.
    var scoringType: ScoringType {
        switch self {
        case .badminton, .padel, .tennis, .pingPong: .sets
        case .football, .basketball: .points
        case .penaltyShootout: .penalties
        case .boxing: .fight
        case .goKart: .placement
        case .running: .time
        case .custom: .winLoss
        }
    }

    /// Modes allowed by the sport (plan.md §2.1). For `.custom` this comes from the `CustomSport`.
    var allowedModes: [MatchMode] {
        switch self {
        case .badminton, .padel, .tennis, .pingPong,
             .football, .basketball, .penaltyShootout: [.oneVsOne, .team]
        case .boxing: [.oneVsOne]
        case .goKart: [.race]
        case .running: [.oneVsOne, .race]
        case .custom: [.oneVsOne]
        }
    }

    /// Players per team in `Team` mode (plan.md §2.1). `nil` if the sport has no team mode.
    var teamSizes: ClosedRange<Int>? {
        switch self {
        case .badminton, .padel, .tennis, .pingPong: 2...2       // doubles
        case .basketball: 2...5
        case .football, .penaltyShootout: 2...11                 // "any size"
        default: nil
        }
    }

    var allowsDraw: Bool {
        switch self {
        case .football, .boxing, .running: true
        default: false
        }
    }

    /// Selectable "Best of" formats (plan.md §2.2). Empty for non-set sports.
    var bestOfOptions: [Int] {
        switch self {
        case .badminton, .padel: [1, 3]
        case .pingPong, .tennis: [1, 3, 5]
        default: []
        }
    }

    /// Default "Best of" format (plan.md §2.2). `nil` for non-set sports.
    var defaultBestOf: Int? {
        switch self {
        case .badminton, .padel, .tennis: 3
        case .pingPong: 5
        default: nil
        }
    }

    /// Rules for a single set (plan.md §2.2). `nil` for non-set sports.
    var setRules: SetRules? {
        switch self {
        case .badminton:
            SetRules(pointsToWin: 21, winBy: 2, maxPoints: 30, tiebreak: nil)
        case .pingPong:
            SetRules(pointsToWin: 11, winBy: 2, maxPoints: nil, tiebreak: nil)
        case .tennis, .padel:
            SetRules(pointsToWin: 6, winBy: 2, maxPoints: 7,
                     tiebreak: TiebreakRules(pointsToWin: 7, winBy: 2))
        default:
            nil
        }
    }
}
