import Foundation
import SwiftData

enum FightMethod: String, Codable, CaseIterable {
    case ko, tko, points, retirement
}

/// One round on the optional score card (10:9 system).
struct RoundScore: Codable, Hashable {
    var round: Int
    var scoreA: Int
    var scoreB: Int
}

@Model
final class FightDetail {
    var match: Match?
    /// `nil` = "Draw" (only allowed with `.points`).
    var winnerSide: Side?
    var method: FightMethod = FightMethod.points
    /// Round the fight ended in (KO, TKO, Retirement).
    var endRound: Int?
    var totalRounds: Int = 3
    var roundScores: [RoundScore] = []

    init(winnerSide: Side?, method: FightMethod, endRound: Int? = nil,
         totalRounds: Int = 3, roundScores: [RoundScore] = []) {
        self.winnerSide = winnerSide
        self.method = method
        self.endRound = endRound
        self.totalRounds = totalRounds
        self.roundScores = roundScores
    }
}
