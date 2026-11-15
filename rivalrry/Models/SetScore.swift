import Foundation
import SwiftData

@Model
final class SetScore {
    var match: Match?
    var index: Int = 0
    var scoreA: Int = 0
    var scoreB: Int = 0
    /// Only for a 7:6 set (Tennis, Padel).
    var tiebreakA: Int?
    var tiebreakB: Int?

    init(index: Int, scoreA: Int, scoreB: Int, tiebreakA: Int? = nil, tiebreakB: Int? = nil) {
        self.index = index
        self.scoreA = scoreA
        self.scoreB = scoreB
        self.tiebreakA = tiebreakA
        self.tiebreakB = tiebreakB
    }
}
