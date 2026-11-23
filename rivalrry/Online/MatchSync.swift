import Foundation
import SwiftData

/// Uploads your online matches and downloads matches others logged with you (Phase 3 step 3).
/// A match is online when every participant, you included, has an online account; matches with
/// local players stay `Local` and only count for you (plan.md §6.2).
enum MatchSync {

    /// `true` if every participant has an online account, so the match needs confirmation.
    static func canGoOnline(_ match: Match) -> Bool {
        !match.participants.isEmpty && match.participants.allSatisfy { $0.player?.cloudUserID != nil }
    }

    /// Called for every new match: online matches start as `Pending` and wait for the upload.
    static func prepareNew(_ match: Match) {
        guard canGoOnline(match) else { return }
        match.status = .pending
        match.needsUpload = true
    }

    /// Called after the creator edited an online match: the version went up, so everyone confirms again.
    static func prepareEdited(_ match: Match) {
        guard match.status != .local else { return }
        match.status = .pending
        match.needsUpload = true
        match.confirmedUserIDs = []
        match.rejectedByUserID = nil
        match.rejectionReason = nil
    }

    // MARK: - Sync

    static func sync(me: Player, context: ModelContext, backend: any OnlineBackend) async throws {
        guard let myUserID = me.cloudUserID else { return }
        let local = try context.fetch(FetchDescriptor<Match>())

        // 1. Upload your new and edited matches.
        for match in local where match.needsUpload && match.createdBy?.isMe == true {
            guard let record = record(from: match) else { continue }
            try await backend.saveMatch(record)
            match.needsUpload = false
        }

        // 2. Download all matches with you and their responses.
        let records = try await backend.fetchMatches()
        let responses = try await backend.fetchResponses(matchIDs: records.map(\.id))
        let players = try context.fetch(FetchDescriptor<Player>())
        var playersByUserID: [String: Player] = [:]
        for player in players {
            guard let userID = player.cloudUserID else { continue }
            // Your own player wins over a stale friend entry with the same ID.
            if playersByUserID[userID] == nil || player.isMe { playersByUserID[userID] = player }
        }
        var localByID = Dictionary(local.map { ($0.id, $0) }) { first, _ in first }

        for record in records {
            if record.creatorUserID == myUserID {
                // Your own match: the content here is the truth, only the answers come from outside.
                if let match = localByID[record.id], !match.needsUpload {
                    apply(MatchConfirmation(record: record, responses: responses), to: match)
                }
                continue
            }
            // Only matches with friends: everyone in it must be known here.
            guard record.userIDs.allSatisfy({ playersByUserID[$0] != nil }) else { continue }
            let match: Match
            if let existing = localByID[record.id] {
                match = existing
                if existing.version < record.version {
                    replaceContent(of: existing, with: record, players: playersByUserID, context: context)
                }
            } else {
                match = Match(sportType: record.sportType)
                match.id = record.id
                context.insert(match)
                localByID[record.id] = match
                replaceContent(of: match, with: record, players: playersByUserID, context: context)
            }
            apply(MatchConfirmation(record: record, responses: responses), to: match)
        }

        // 3. Matches others deleted disappear here too.
        let onlineIDs = Set(records.map(\.id))
        for match in local where match.status != .local && match.createdBy?.isMe != true
            && !onlineIDs.contains(match.id) {
            context.delete(match)
        }
    }

    /// Deletes your online match on the server too (allowed while `Pending` or `Rejected`).
    static func deleteOnline(matchID: UUID, backend: any OnlineBackend) async throws {
        try await backend.deleteMatch(id: matchID)
    }

    // MARK: - Converting

    /// The online record of a local match, or `nil` if a player has no online account.
    static func record(from match: Match) -> MatchRecord? {
        guard let creator = match.createdBy?.cloudUserID, canGoOnline(match) else { return nil }
        let participants = match.participants.compactMap { participant -> MatchRecord.Participant? in
            guard let userID = participant.player?.cloudUserID else { return nil }
            return .init(userID: userID, side: participant.side, place: participant.place,
                         timeMs: participant.timeMs, fastestLapMs: participant.fastestLapMs, dnf: participant.dnf)
        }
        return MatchRecord(
            id: match.id, creatorUserID: creator, version: match.version, sportType: match.sportType,
            customSport: match.customSport.map {
                .init(id: $0.id, name: $0.name, symbolName: $0.symbolName, scoringType: $0.scoringType,
                      allowsDraw: $0.allowsDraw, allowsTeams: $0.allowsTeams,
                      pointsPerSet: $0.pointsPerSet, winBy: $0.winBy)
            },
            mode: match.mode, date: match.date, bestOf: match.bestOf, note: match.note, location: match.location,
            penaltyShotsPerSide: match.penaltyShotsPerSide, distanceMeters: match.distanceMeters,
            retiredSide: match.retiredSide, isImported: match.isImported, participants: participants,
            sets: match.orderedSets.map {
                .init(index: $0.index, scoreA: $0.scoreA, scoreB: $0.scoreB,
                      tiebreakA: $0.tiebreakA, tiebreakB: $0.tiebreakB)
            },
            penalties: match.orderedPenalties.map {
                .init(index: $0.index, side: $0.side, scored: $0.scored, isSuddenDeath: $0.isSuddenDeath)
            },
            fight: match.fight.map {
                .init(winnerSide: $0.winnerSide, method: $0.method, endRound: $0.endRound,
                      totalRounds: $0.totalRounds, roundScores: $0.roundScores)
            },
            createdAt: match.createdAt, updatedAt: match.updatedAt)
    }

    static func apply(_ confirmation: MatchConfirmation, to match: Match) {
        match.status = confirmation.status
        match.confirmedUserIDs = confirmation.confirmedUserIDs
        match.rejectedByUserID = confirmation.rejectedByUserID
        match.rejectionReason = confirmation.rejectionReason
    }

    /// Overwrites a match someone else created with the downloaded version.
    private static func replaceContent(of match: Match, with record: MatchRecord,
                                       players: [String: Player], context: ModelContext) {
        for participant in match.participants { context.delete(participant) }
        for set in match.sets { context.delete(set) }
        for shot in match.penalties { context.delete(shot) }
        if let fight = match.fight { context.delete(fight) }

        match.sportType = record.sportType
        match.customSport = record.customSport.map { customSport(for: $0, context: context) }
        match.mode = record.mode
        match.date = record.date
        match.bestOf = record.bestOf
        match.note = record.note
        match.location = record.location
        match.penaltyShotsPerSide = record.penaltyShotsPerSide
        match.distanceMeters = record.distanceMeters
        match.retiredSide = record.retiredSide
        match.isImported = record.isImported
        match.createdBy = players[record.creatorUserID]
        match.createdAt = record.createdAt
        match.updatedAt = record.updatedAt
        match.version = record.version
        match.needsUpload = false

        match.participants = record.participants.map {
            MatchParticipant(player: players[$0.userID], side: $0.side, place: $0.place, timeMs: $0.timeMs,
                             fastestLapMs: $0.fastestLapMs, dnf: $0.dnf)
        }
        match.sets = record.sets.map {
            SetScore(index: $0.index, scoreA: $0.scoreA, scoreB: $0.scoreB, tiebreakA: $0.tiebreakA, tiebreakB: $0.tiebreakB)
        }
        match.penalties = record.penalties.map {
            PenaltyShot(index: $0.index, side: $0.side, scored: $0.scored, isSuddenDeath: $0.isSuddenDeath)
        }
        match.fight = record.fight.map {
            FightDetail(winnerSide: $0.winnerSide, method: $0.method, endRound: $0.endRound,
                        totalRounds: $0.totalRounds, roundScores: $0.roundScores)
        }
    }

    /// The local custom sport for a downloaded match; added to your sports if you don't have it yet.
    private static func customSport(for record: MatchRecord.CustomSportRecord, context: ModelContext) -> CustomSport {
        let id = record.id
        if let existing = try? context.fetch(FetchDescriptor<CustomSport>(predicate: #Predicate { $0.id == id })).first {
            return existing
        }
        let sport = CustomSport(name: record.name, symbolName: record.symbolName, scoringType: record.scoringType,
                                allowsDraw: record.allowsDraw, allowsTeams: record.allowsTeams,
                                pointsPerSet: record.pointsPerSet, winBy: record.winBy)
        sport.id = record.id
        context.insert(sport)
        return sport
    }
}

extension OnlineFriends {
    /// Friends first (new friends become players), then matches, so their matches can be matched to them.
    func syncAll(me: Player, context: ModelContext) async throws {
        try await refresh(me: me, context: context)
        try await MatchSync.sync(me: me, context: context, backend: backend)
    }

    /// After saving or editing a match.
    func syncMatches(me: Player, context: ModelContext) async throws {
        try await MatchSync.sync(me: me, context: context, backend: backend)
    }
}
