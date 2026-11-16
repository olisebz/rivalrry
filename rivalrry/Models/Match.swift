import Foundation
import SwiftData

enum Side: String, Codable, CaseIterable {
    case a, b

    var opponent: Side { self == .a ? .b : .a }
}

enum MatchStatus: String, Codable, CaseIterable {
    /// Phase 1–2: entered locally, counts immediately.
    case local
    case pending, confirmed, rejected
}

/// One entered game, race or fight.
/// Winner and Elo are never stored; they are computed from this data (plan.md §5).
@Model
final class Match {
    var id: UUID = UUID()
    var sportType: SportType = SportType.badminton
    var customSport: CustomSport?
    var mode: MatchMode = MatchMode.oneVsOne
    var date: Date = Date()
    var bestOf: Int?
    var note: String?
    var location: String?
    @Attribute(.externalStorage) var photo: Data?
    var status: MatchStatus = MatchStatus.local
    var createdBy: Player?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var version: Int = 1
    var isImported: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \MatchParticipant.match)
    var participants: [MatchParticipant] = []
    @Relationship(deleteRule: .cascade, inverse: \SetScore.match)
    var sets: [SetScore] = []
    @Relationship(deleteRule: .cascade, inverse: \PenaltyShot.match)
    var penalties: [PenaltyShot] = []
    @Relationship(deleteRule: .cascade, inverse: \FightDetail.match)
    var fight: FightDetail?

    /// Only for `.penalties`: regular shots per side (3, 5 or 10).
    var penaltyShotsPerSide: Int?
    /// Only for `.time` (Running).
    var distanceMeters: Int?
    /// Side that gave up (`"Match not finished"`), counts as a win for the other side.
    var retiredSide: Side?

    init(sportType: SportType, customSport: CustomSport? = nil, mode: MatchMode = .oneVsOne,
         date: Date = Date(), bestOf: Int? = nil, note: String? = nil,
         status: MatchStatus = .local, createdBy: Player? = nil,
         distanceMeters: Int? = nil, retiredSide: Side? = nil) {
        self.sportType = sportType
        self.customSport = customSport
        self.mode = mode
        self.date = date
        self.bestOf = bestOf
        self.note = note
        self.status = status
        self.createdBy = createdBy
        self.distanceMeters = distanceMeters
        self.retiredSide = retiredSide
    }

    // SwiftData to-many relationships are unordered; these restore the entry order.
    var orderedSets: [SetScore] { sets.sorted { $0.index < $1.index } }
    var orderedPenalties: [PenaltyShot] { penalties.sorted { $0.index < $1.index } }
}
