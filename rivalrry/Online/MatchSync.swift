import Foundation
import SwiftData

/// Uploads your online matches and downloads matches others logged with you (Phase 3 steps 3–4).
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

    /// Called after the creator edited a `Pending` or `Rejected` match: the version went up, so everyone
    /// confirms again. Confirmed matches go through `proposeChange` instead.
    static func prepareEdited(_ match: Match) {
        guard match.status == .pending || match.status == .rejected else { return }
        match.status = .pending
        match.needsUpload = true
        match.confirmedUserIDs = []
        match.rejectedByUserID = nil
        match.rejectionReason = nil
    }

    // MARK: - Actions

    /// "Edit" on a confirmed match (plan.md §4 S3): the change becomes a new request, the old result
    /// keeps counting until all opponents confirm it.
    static func proposeChange(_ draft: MatchDraft, to match: Match, context: ModelContext) {
        guard match.status == .confirmed, let base = record(from: match) else { return }
        let version = max(match.version, match.pendingChange?.record.version ?? 0) + 1
        // Write the draft into the match to get the new record, then put the confirmed result back.
        draft.apply(to: match, context: context)
        let changed = record(from: match)
        replaceContent(of: match, with: base, players: players(of: match), context: context)
        guard var change = changed else { return }
        change.version = version
        change.proposedChanges = []
        match.pendingChange = PendingChange(record: change,
                                            confirmation: MatchConfirmation(record: change, responses: []))
        match.needsUpload = true
    }

    /// "Remind" (plan.md §4 S3); the push follows in step 5.
    static func remind(_ match: Match, me: Player, now: Date = Date()) {
        guard match.canRemind(by: me, now: now) else { return }
        match.remindedAt = now
        match.needsUpload = true
    }

    // Answers go through the `Outbox` (sent later when offline) and show here right away;
    // the next sync replaces them with what's online.

    /// "Confirm" in S6: answers the pending match or the pending change.
    static func confirm(_ match: Match, me: Player, backend: any OnlineBackend) async throws {
        try await answer(match, me: me, kind: .confirm, reason: nil, backend: backend)
    }

    /// "Reject" in S6; the reason is required (plan.md §4 S6).
    static func reject(_ match: Match, reason: String, me: Player, backend: any OnlineBackend) async throws {
        let reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else { return }
        try await answer(match, me: me, kind: .reject, reason: reason, backend: backend)
    }

    private static func answer(_ match: Match, me: Player, kind: MatchResponse.Kind, reason: String?,
                               backend: any OnlineBackend) async throws {
        guard let userID = me.cloudUserID, let context = match.modelContext,
              match.needsConfirmation(by: me) else { return }
        let answersChange = match.status != .pending
        let version = answersChange ? (match.pendingChange?.record.version ?? match.version) : match.version
        try await Outbox.send(.response(MatchResponse(matchID: match.id, matchVersion: version, userID: userID,
                                                      kind: kind, reason: reason)),
                              backend: backend, context: context)

        if answersChange, var change = match.pendingChange {
            change.confirmation.apply(kind, by: userID, reason: reason, opponents: match.confirmingUserIDs)
            match.pendingChange = change
        } else {
            var confirmation = MatchConfirmation(match)
            confirmation.apply(kind, by: userID, reason: reason, opponents: match.confirmingUserIDs)
            apply(confirmation, to: match)
        }
    }

    /// "Request deletion" for a confirmed match.
    static func requestDeletion(_ match: Match, me: Player, backend: any OnlineBackend) async throws {
        guard let userID = me.cloudUserID, let context = match.modelContext,
              match.canRequestDeletion(by: me) else { return }
        let request = MatchResponse(matchID: match.id, matchVersion: match.version, userID: userID, kind: .requestDelete)
        try await Outbox.send(.response(request), backend: backend, context: context)
        let everyone = ([match.createdBy?.cloudUserID].compactMap { $0 } + match.confirmingUserIDs)
        match.deletionRequest = DeletionRequest(requestedBy: userID, requestedAt: request.createdAt,
                                                approverUserIDs: everyone.filter { $0 != userID }, approvedUserIDs: [])
    }

    /// "Approve" / "Decline" in S6 "Deletion requests".
    static func answerDeletion(_ match: Match, approve: Bool, me: Player, backend: any OnlineBackend) async throws {
        guard let userID = me.cloudUserID, let context = match.modelContext,
              match.needsDeletionAnswer(by: me) else { return }
        try await Outbox.send(.response(MatchResponse(matchID: match.id, matchVersion: match.version, userID: userID,
                                                      kind: approve ? .approveDelete : .declineDelete)),
                              backend: backend, context: context)
        if approve, var request = match.deletionRequest {
            request.approvedUserIDs.append(userID)
            match.deletionRequest = request
        } else {
            match.deletionRequest = nil
        }
    }

    /// Deletes your online match on the server too (allowed while `Pending` or `Rejected`).
    static func deleteOnline(matchID: UUID, backend: any OnlineBackend, context: ModelContext) async throws {
        try await Outbox.send(.deleteMatch(matchID), backend: backend, context: context)
    }

    // MARK: - Sync

    static func sync(me: Player, context: ModelContext, backend: any OnlineBackend) async throws {
        guard let myUserID = me.cloudUserID else { return }
        // 0. First what waited offline, then the links of your friends (they decide which old matches
        //    you import, plan.md §6.3).
        try await Outbox.flush(backend: backend, context: context)
        try await AccountLinking.syncLinks(me: me, context: context, backend: backend)
        let local = try context.fetch(FetchDescriptor<Match>())

        // 1. Upload your new and edited matches, changes and reminders.
        try await upload(local, backend: backend)

        // 2. Download all matches with you and their responses.
        let records = try await backend.fetchMatches()
        let responses = try await backend.fetchResponses(matchIDs: records.map(\.id))
        var playersByUserID: [String: Player] = [:]
        for player in try context.fetch(FetchDescriptor<Player>()) {
            guard let userID = player.cloudUserID else { continue }
            // Your own player wins over a stale friend entry with the same ID.
            if playersByUserID[userID] == nil || player.isMe { playersByUserID[userID] = player }
        }
        var localByID = Dictionary(local.map { ($0.id, $0) }) { first, _ in first }
        var deletedIDs: Set<UUID> = []

        for record in records {
            let isMine = record.creatorUserID == myUserID
            let deletion = DeletionRequest(record: record, responses: responses)

            // Everyone agreed to delete: gone for everyone; the creator removes it online.
            if deletion?.isApproved == true {
                if isMine { try await backend.deleteMatch(id: record.id) }
                if let match = localByID[record.id] {
                    context.delete(match)
                    localByID[record.id] = nil
                }
                deletedIDs.insert(record.id)
                continue
            }

            // A confirmed change replaces the old result; an open one is kept next to it.
            var effective = record
            var change: PendingChange?
            if let proposed = record.proposedChange {
                let confirmation = MatchConfirmation(record: proposed, responses: responses)
                if confirmation.status == .confirmed {
                    effective = proposed
                    effective.proposedChanges = []
                } else {
                    change = PendingChange(record: proposed, confirmation: confirmation)
                }
            }
            let confirmation = MatchConfirmation(record: effective, responses: responses)

            if isMine {
                // Your own match: the content here is the truth, only the answers come from outside.
                guard let match = localByID[record.id], !match.needsUpload else { continue }
                if effective.version != record.version {
                    // Your change was confirmed: take it over and upload the merged record.
                    replaceContent(of: match, with: effective, players: playersByUserID, context: context)
                    match.needsUpload = true
                }
                match.pendingChange = change
                match.deletionRequest = deletion
                apply(confirmation, to: match)
                // A rejected import goes back to you only and keeps counting there (plan.md §6.3 point 5).
                if record.isImported, confirmation.status == .rejected {
                    try await backend.deleteMatch(id: record.id)
                    match.status = .local
                    match.localOnly = .rejectedImport
                    deletedIDs.insert(record.id)
                }
                continue
            }

            // Only matches with friends: everyone in it must be known here.
            guard effective.userIDs.allSatisfy({ playersByUserID[$0] != nil }) else { continue }
            let match: Match
            if let existing = localByID[record.id] {
                match = existing
                if existing.version < effective.version {
                    replaceContent(of: existing, with: effective, players: playersByUserID, context: context)
                }
            } else {
                match = Match(sportType: effective.sportType)
                match.id = record.id
                context.insert(match)
                localByID[record.id] = match
                replaceContent(of: match, with: effective, players: playersByUserID, context: context)
            }
            match.pendingChange = change
            match.deletionRequest = deletion
            match.remindedAt = record.remindedAt
            apply(confirmation, to: match)
        }

        // 3. Merged changes go up right away.
        try await upload(Array(localByID.values), backend: backend)

        // 4. Matches others deleted disappear here too.
        let onlineIDs = Set(records.map(\.id))
        for match in local where !deletedIDs.contains(match.id) && match.status != .local
            && match.createdBy?.isMe != true && !onlineIDs.contains(match.id) {
            context.delete(match)
        }
    }

    private static func upload(_ matches: [Match], backend: any OnlineBackend) async throws {
        for match in matches where match.needsUpload && match.createdBy?.isMe == true {
            guard var record = record(from: match) else { continue }
            record.proposedChange = match.pendingChange?.record
            try await backend.saveMatch(record)
            match.needsUpload = false
        }
    }

    // MARK: - Converting

    /// The online record of a local match, or `nil` if a player has no online account.
    /// The proposed change is added by `upload`.
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
            createdAt: match.createdAt, updatedAt: match.updatedAt, remindedAt: match.remindedAt)
    }

    static func apply(_ confirmation: MatchConfirmation, to match: Match) {
        match.status = confirmation.status
        match.confirmedUserIDs = confirmation.confirmedUserIDs
        match.rejectedByUserID = confirmation.rejectedByUserID
        match.rejectionReason = confirmation.rejectionReason
    }

    /// The players of a match by user ID.
    private static func players(of match: Match) -> [String: Player] {
        Dictionary(match.participants.compactMap { participant in
            participant.player.flatMap { player in player.cloudUserID.map { ($0, player) } }
        }) { first, _ in first }
    }

    /// Overwrites the content of a match with a record (downloaded match, merged or undone change).
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

    /// After saving, editing or answering a match.
    func syncMatches(me: Player, context: ModelContext) async throws {
        try await MatchSync.sync(me: me, context: context, backend: backend)
    }
}
