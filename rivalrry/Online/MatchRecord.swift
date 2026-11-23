import Foundation

/// A match as stored online (plan.md §6.1). Belongs to the creator; only they can change it.
/// Players are referenced by their iCloud user ID.
struct MatchRecord: Identifiable, Equatable, Codable, Sendable {
    struct Participant: Equatable, Codable, Sendable {
        var userID: String
        var side: Side?
        var place: Int?
        var timeMs: Int?
        var fastestLapMs: Int?
        var dnf: Bool = false
    }

    struct SetRecord: Equatable, Codable, Sendable {
        var index: Int
        var scoreA: Int
        var scoreB: Int
        var tiebreakA: Int?
        var tiebreakB: Int?
    }

    struct Penalty: Equatable, Codable, Sendable {
        var index: Int
        var side: Side
        var scored: Bool
        var isSuddenDeath: Bool
    }

    struct Fight: Equatable, Codable, Sendable {
        var winnerSide: Side?
        var method: FightMethod
        var endRound: Int?
        var totalRounds: Int
        var roundScores: [RoundScore]
    }

    /// Custom sports travel with the match, so the opponents' apps can add them (Phase 3 decision).
    struct CustomSportRecord: Equatable, Codable, Sendable {
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
    /// Last "Remind" by the creator (plan.md §4 S3: once every 24 h while `Pending`).
    var remindedAt: Date?
    /// A change to a confirmed match, waiting for the opponents (plan.md §4 S3). Holds at most one
    /// record (an array only because a struct can't contain itself); use `proposedChange`.
    var proposedChanges: [MatchRecord] = []

    /// The full new version of a confirmed match. The old result keeps counting until it is confirmed.
    var proposedChange: MatchRecord? {
        get { proposedChanges.first }
        set { proposedChanges = newValue.map { [$0] } ?? [] }
    }

    /// Everyone who has to confirm: the other team (1v1, Team) or everyone else (Race).
    /// Partners on the creator's team don't confirm (plan.md §0: "all opponents").
    var opponentUserIDs: [String] {
        let creatorSide = participants.first { $0.userID == creatorUserID }?.side
        return participants
            .filter { $0.userID != creatorUserID && (mode == .race || $0.side != creatorSide) }
            .map(\.userID)
    }

    var userIDs: [String] { participants.map(\.userID) }

    /// Who can ask to delete a confirmed match: the creator and everyone who confirms (Phase 3 decision).
    var deletionUserIDs: [String] { [creatorUserID] + opponentUserIDs }
}

/// A user's answer to a match (plan.md §6.1). Belongs to that user.
struct MatchResponse: Identifiable, Equatable, Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        /// Answers to one version of the match.
        case confirm, reject
        /// "Request deletion" and the answers to it (any version).
        case requestDelete, approveDelete, declineDelete

        var isDeletion: Bool { self == .requestDelete || self == .approveDelete || self == .declineDelete }
    }

    var id: UUID = UUID()
    var matchID: UUID
    var matchVersion: Int
    var userID: String
    var kind: Kind
    /// Required for `.reject`.
    var reason: String?
    var createdAt: Date = Date()
}

/// The status of one version of an online match, worked out from the responses (plan.md §6.1).
struct MatchConfirmation: Equatable, Codable {
    var status: MatchStatus
    var confirmedUserIDs: [String] = []
    var rejectedByUserID: String?
    var rejectionReason: String?

    /// `Confirmed` once every opponent confirmed the version, `Rejected` as soon as one rejected it,
    /// otherwise `Pending`. Answers to other versions don't count.
    init(record: MatchRecord, responses: [MatchResponse]) {
        let current = responses.filter {
            $0.matchID == record.id && $0.matchVersion == record.version && !$0.kind.isDeletion
        }
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

/// A proposed change to a confirmed match and where its confirmation stands. Stored on the local match.
struct PendingChange: Equatable, Codable {
    var record: MatchRecord
    var confirmation: MatchConfirmation
}

/// An open "Request deletion" (Phase 3 decision: any participant who confirms, or the creator, can ask;
/// everyone else of them must approve; one "Decline" ends it).
struct DeletionRequest: Equatable, Codable {
    var requestedBy: String
    var requestedAt: Date
    /// Everyone who has to approve.
    var approverUserIDs: [String]
    var approvedUserIDs: [String]

    var isApproved: Bool { Set(approverUserIDs).isSubset(of: approvedUserIDs) }

    /// The open request, or `nil` if there is none or someone declined it.
    init?(record: MatchRecord, responses: [MatchResponse]) {
        let deletion = responses.filter { $0.matchID == record.id && $0.kind.isDeletion }
        let allowed = record.deletionUserIDs
        guard let request = deletion
            .filter({ $0.kind == .requestDelete && allowed.contains($0.userID) })
            .max(by: { $0.createdAt < $1.createdAt }) else { return nil }
        // Only answers given after the request count.
        let answers = deletion.filter { $0.createdAt >= request.createdAt && $0.userID != request.userID }
        if answers.contains(where: { $0.kind == .declineDelete && allowed.contains($0.userID) }) { return nil }
        requestedBy = request.userID
        requestedAt = request.createdAt
        approverUserIDs = allowed.filter { $0 != request.userID }
        approvedUserIDs = approverUserIDs.filter { id in answers.contains { $0.userID == id && $0.kind == .approveDelete } }
    }
}
