import Foundation
import SwiftData

@Model
final class MatchParticipant {
    var match: Match?
    /// `nil` after the player was deleted ("Deleted Player").
    var player: Player?
    /// `nil` for races.
    var side: Side?
    /// Finishing place for races.
    var place: Int?
    /// Running time in milliseconds.
    var timeMs: Int?
    /// Fastest lap in milliseconds (Go-Kart).
    var fastestLapMs: Int?
    var dnf: Bool = false

    init(player: Player?, side: Side? = nil, place: Int? = nil, timeMs: Int? = nil,
         fastestLapMs: Int? = nil, dnf: Bool = false) {
        self.player = player
        self.side = side
        self.place = place
        self.timeMs = timeMs
        self.fastestLapMs = fastestLapMs
        self.dnf = dnf
    }
}
