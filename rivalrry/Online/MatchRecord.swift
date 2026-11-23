import Foundation

/// A match as stored online (plan.md §6.1). Belongs to the creator; only they can change it.
/// Players are referenced by their iCloud user ID.
struct MatchRecord: Identifiable, Equatable, Sendable {
    struct Participant: Equatable, Sendable {
        var userID: String
        var side: Side?
        var place: Int?
        var timeMs: Int?
        var fastestLapMs: Int?
        var dnf: Bool = false
    }

    struct SetRecord: Equatable, Sendable {
        var index: Int
        var scoreA: Int
        var scoreB: Int
        var tiebreakA: Int?
        var tiebreakB: Int?
    }

    struct Penalty: Equatable, Sendable {
        var index: Int
        var side: Side
        var scored: Bool
        var isSuddenDeath: Bool
    }

    struct Fight: Equatable, Sendable {
        var winnerSide: Side?
        var method: FightMethod
        var endRound: Int?
        var totalRounds: Int
        var roundScores: [RoundScore]
    }

    /// Custom sports travel with the match, so the opponents' apps can add them (Phase 3 decision).
    struct CustomSportRecord: Equatable, Sendable {
        var id: UUID
        var name: String
        var symbolName: String
        var scoringType: ScoringType
        var allowsDraw: Bool
        var allowsTeams: Bool
        var pointsPerSet: Int?
        var winBy: Int?
    }

    var id: UUID
    var creatorUserID: String
    /// Goes up with every edit; confirmations only count for the current version.
    var version: Int
    var sportType: SportType
    var customSport: CustomSportRecord?
    var mode: MatchMode
    var date: Date
    var bestOf: Int?
    var note: String?
    var location: String?
    var penaltyShotsPerSide: Int?
    var distanceMeters: Int?
    var retiredSide: Side?
    var isImported: Bool = false
    var participants: [Participant]
    var sets: [SetRecord] = []
    var penalties: [Penalty] = []
    var fight: Fight?
    var createdAt: Date
    var updatedAt: Date

    /// Everyone who has to confirm: the other team (1v1, Team) or everyone else (Race).
    /// Partners on the creator's team don't confirm (plan.md §0: "all opponents").
    var opponentUserIDs: [String] {
        let creatorSide = participants.first { $0.userID == creatorUserID }?.side
        return participants
            .filter { $0.userID != creatorUserID && (mode == .race || $0.side != creatorSide) }
            .map(\.userID)
    }

    var userIDs: [String] { participants.map(\.userID) }
}

/// An opponent's answer to one version of a match (plan.md §6.1). Belongs to the opponent.
struct MatchResponse: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable { case confirm, reject, approveDelete }

    var id: UUID = UUID()
    var matchID: UUID
    var matchVersion: Int
    var userID: String
    var kind: Kind
    /// Required for `.reject`.
    var reason: String?
    var createdAt: Date = Date()
}

/// The status of an online match, worked out from the responses (plan.md §6.1).
struct MatchConfirmation: Equatable {
    var status: MatchStatus
    var confirmedUserIDs: [String] = []
    var rejectedByUserID: String?
    var rejectionReason: String?

    /// `Confirmed` once every opponent confirmed the current version, `Rejected` as soon as one rejected it,
    /// otherwise `Pending`. Answers to older versions don't count.
    init(record: MatchRecord, responses: [MatchResponse]) {
        let current = responses.filter { $0.matchID == record.id && $0.matchVersion == record.version }
        let opponents = record.opponentUserIDs
        // The newest answer per opponent counts.
        let latest = Dictionary(current.filter { opponents.contains($0.userID) }.map { ($0.userID, $0) }) {
            $0.createdAt >= $1.createdAt ? $0 : $1
        }
        confirmedUserIDs = opponents.filter { latest[$0]?.kind == .confirm }
        if let rejection = latest.values.filter({ $0.kind == .reject }).min(by: { $0.createdAt < $1.createdAt }) {
            status = .rejected
            rejectedByUserID = rejection.userID
            rejectionReason = rejection.reason
        } else if !opponents.isEmpty, confirmedUserIDs.count == opponents.count {
            status = .confirmed
        } else {
            status = .pending
        }
    }
}
