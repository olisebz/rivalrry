import Foundation
import SwiftData

@Model
final class PenaltyShot {
    var match: Match?
    var index: Int = 0
    var side: Side = Side.a
    var scored: Bool = false
    var isSuddenDeath: Bool = false

    init(index: Int, side: Side, scored: Bool, isSuddenDeath: Bool = false) {
        self.index = index
        self.side = side
        self.scored = scored
        self.isSuddenDeath = isSuddenDeath
    }
}
