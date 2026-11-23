import Foundation
import SwiftData

/// "Link to Account" and the import of old local matches (plan.md §6.3, Phase 3 step 5).
///
/// Rules agreed with the user:
/// - Whoever links first imports right away (if the friend hasn't linked yet).
/// - If both linked before anyone imported, the second one is asked "Who imports?".
/// - If the friend already imported, your own old matches stay as "Local only" and stop counting.
/// - Imported matches the friend rejects go back to `Local` ("Local only") and keep counting for you.
/// - Matches with several local players wait until all of them are linked.
enum AccountLinking {

    enum Outcome: Equatable {
        /// Your old matches are sent to the friend for confirmation.
        case importing(count: Int)
        /// The friend already imported; yours stay "Local only".
        case alreadyImported(by: String, count: Int)
        /// Both of you have old matches and nobody imported yet: "Who imports?".
        case chooseImporter(friendCount: Int)
        case nothingToImport
    }

    /// Online friends a local friend can be linked to.
    static func candidates(in players: [Player]) -> [Player] {
        players.filter { !$0.isMe && $0.cloudUserID != nil }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Your old local matches with `friend` that could be imported.
    static func localMatches(with friend: Player, me: Player, in matches: [Match]) -> [Match] {
        matches.filter { $0.status == .local && $0.localOnly == nil && $0.includes(me) && $0.includes(friend) }
    }

    /// Links the local friend `local` to the online friend `online`: both become one player, then the
    /// old matches are imported (or not) following the rules above.
    @discardableResult
    static func link(_ local: Player, to online: Player, me: Player, context: ModelContext,
                     backend: any OnlineBackend) async throws -> Outcome {
        guard let myUserID = me.cloudUserID, let friendUserID = online.cloudUserID,
              local.cloudUserID == nil, !local.isMe, local.id != online.id else { return .nothingToImport }

        merge(online, into: local, context: context)
        let matches = try context.fetch(FetchDescriptor<Match>())
        let myCount = localMatches(with: local, me: me, in: matches).count

        let links = try await backend.fetchLinks()
        let theirs = links.first { $0.userID == friendUserID && $0.friendUserID == myUserID }
        var mine = LinkRecord(userID: myUserID, friendUserID: friendUserID, localMatchCount: myCount)
        let outcome: Outcome

        if theirs?.importerUserID == friendUserID {
            local.importsMatches = false
            mine.importerUserID = friendUserID
            outcome = .alreadyImported(by: local.shortName, count: theirs?.localMatchCount ?? 0)
        } else if theirs?.importerUserID == myUserID {
            local.importsMatches = true
            mine.importerUserID = myUserID
            outcome = myCount > 0 ? .importing(count: myCount) : .nothingToImport
        } else if let theirs, theirs.localMatchCount > 0, myCount > 0 {
            outcome = .chooseImporter(friendCount: theirs.localMatchCount)
        } else if myCount > 0 {
            local.importsMatches = true
            mine.importerUserID = myUserID
            outcome = .importing(count: myCount)
        } else {
            outcome = .nothingToImport
        }

        try await backend.saveLink(mine)
        applyImports(me: me, context: context)
        return outcome
    }

    /// The answer to "Who imports?".
    static func chooseImporter(youImport: Bool, friend: Player, me: Player, context: ModelContext,
                               backend: any OnlineBackend) async throws {
        guard let myUserID = me.cloudUserID, let friendUserID = friend.cloudUserID else { return }
        let matches = try context.fetch(FetchDescriptor<Match>())
        friend.importsMatches = youImport
        try await backend.saveLink(LinkRecord(
            userID: myUserID, friendUserID: friendUserID,
            localMatchCount: localMatches(with: friend, me: me, in: matches).count,
            importerUserID: youImport ? myUserID : friendUserID))
        applyImports(me: me, context: context)
    }

    /// Reads the friends' links (did they import, or choose you?), then marks matches. Runs with every sync.
    static func syncLinks(me: Player, context: ModelContext, backend: any OnlineBackend) async throws {
        guard let myUserID = me.cloudUserID else { return }
        let players = try context.fetch(FetchDescriptor<Player>())
        for link in try await backend.fetchLinks() where link.friendUserID == myUserID {
            guard let friend = players.first(where: { $0.cloudUserID == link.userID && !$0.isMe }) else { continue }
            if link.importerUserID == link.userID, friend.importsMatches != true {
                friend.importsMatches = false
            } else if link.importerUserID == myUserID, friend.importsMatches == nil {
                friend.importsMatches = true
            }
        }
        applyImports(me: me, context: context)
    }

    /// Imports every old match whose players are all linked and agreed that you import; marks your copies
    /// as "Local only" where a friend imports theirs.
    static func applyImports(me: Player, context: ModelContext) {
        guard me.cloudUserID != nil, let matches = try? context.fetch(FetchDescriptor<Match>()) else { return }
        for match in matches where match.status == .local && match.localOnly == nil && match.includes(me) {
            let others = match.participants.compactMap(\.player).filter { !$0.isMe }
            guard !others.isEmpty else { continue }
            if others.contains(where: { $0.importsMatches == false }) {
                match.localOnly = .duplicate
            } else if others.allSatisfy({ $0.cloudUserID != nil && $0.importsMatches == true }),
                      MatchSync.canGoOnline(match) {
                match.createdBy = me
                match.isImported = true
                match.status = .pending
                match.needsUpload = true
            }
        }
    }

    /// One player instead of two: matches of the online entry move to the local friend, who takes over
    /// the online account. The online entry is deleted.
    private static func merge(_ online: Player, into local: Player, context: ModelContext) {
        for participant in online.participations { participant.player = local }
        if let matches = try? context.fetch(FetchDescriptor<Match>()) {
            for match in matches where match.createdBy?.id == online.id { match.createdBy = local }
        }
        local.cloudUserID = online.cloudUserID
        local.username = online.username
        local.name = online.name
        local.colorHex = online.colorHex
        local.photo = online.photo ?? local.photo
        local.importsMatches = online.importsMatches
        local.isArchived = local.isArchived && online.isArchived
        context.delete(online)
    }
}

extension Match {
    /// Old match that waits for more players to link (plan.md §6.3 point 6).
    var playersStillToJoin: Int {
        guard status == .local, localOnly == nil, !isImported else { return 0 }
        let others = participants.compactMap(\.player).filter { !$0.isMe }
        guard others.contains(where: { $0.importsMatches == true }) else { return 0 }
        return others.filter { $0.cloudUserID == nil }.count
    }

    /// S3 note for local matches after linking: "Local only", "Waiting for 2 more players to join".
    var localNote: String? {
        switch localOnly {
        case .rejectedImport:
            let name = participants.first { $0.player?.cloudUserID == rejectedByUserID }?.player?.shortName
            guard let name else { return "Local only" }
            guard let reason = rejectionReason, !reason.isEmpty else { return "Local only · Rejected by \(name)" }
            return "Local only · Rejected by \(name): \(reason)"
        case .duplicate:
            let importer = participants.first { $0.player?.importsMatches == false }?.player?.shortName
            return importer.map { "Local only · \($0) imported these matches" } ?? "Local only"
        case nil:
            let count = playersStillToJoin
            guard count > 0 else { return nil }
            return count == 1 ? "Waiting for 1 more player to join" : "Waiting for \(count) more players to join"
        }
    }
}
