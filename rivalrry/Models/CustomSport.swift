import Foundation
import SwiftData

/// A user-defined sport (Phase 2).
@Model
final class CustomSport {
    var id: UUID = UUID()
    var name: String = ""
    /// SF Symbol name (design.md §5). Replaces the emoji from plan.md.
    var symbolName: String = "trophy"
    var scoringType: ScoringType = ScoringType.winLoss
    var allowsDraw: Bool = false
    var allowsTeams: Bool = false
    /// Only for `.sets`.
    var pointsPerSet: Int?
    /// Only for `.sets`.
    var winBy: Int?

    init(name: String, symbolName: String = "trophy", scoringType: ScoringType = .winLoss,
         allowsDraw: Bool = false, allowsTeams: Bool = false,
         pointsPerSet: Int? = nil, winBy: Int? = nil) {
        self.name = name
        self.symbolName = symbolName
        self.scoringType = scoringType
        self.allowsDraw = allowsDraw
        self.allowsTeams = allowsTeams
        self.pointsPerSet = pointsPerSet
        self.winBy = winBy
    }
}

extension CustomSport {
    /// Scoring types you can pick (plan.md §2.2 "Custom sport").
    static let scoringTypes: [ScoringType] = [.winLoss, .points, .sets, .placement, .time]
    /// Placement and Time are races, so only these can be played in teams.
    static let teamScoringTypes: [ScoringType] = [.winLoss, .points, .sets]
    static let drawScoringTypes: [ScoringType] = [.winLoss, .points]

    static let defaultPointsPerSet = 11
    static let defaultWinBy = 2
    static let pointsPerSetRange = 1...99
    static let winByRange = 1...5

    /// About 20 symbols to choose from (design.md §5).
    static let symbols = [
        "trophy", "figure.golf", "figure.bowling", "figure.climbing", "figure.volleyball",
        "figure.handball", "figure.hockey", "figure.skiing.downhill", "figure.pool.swim", "figure.outdoor.cycle",
        "figure.archery", "figure.fencing", "figure.skating", "figure.surfing", "figure.disc.sports",
        "figure.cricket", "figure.rugby", "target", "gamecontroller", "dice",
    ]
}

extension ScoringType {
    /// Names in the custom sport form (plan.md §2.2).
    var customTitle: String {
        switch self {
        case .winLoss: "Win / Loss"
        case .points: "Points"
        case .sets: "Sets"
        case .placement: "Placement"
        case .time: "Time"
        case .penalties: "Penalties"
        case .fight: "Fight"
        }
    }
}
