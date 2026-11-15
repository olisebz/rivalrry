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
