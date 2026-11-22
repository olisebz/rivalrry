import Foundation
import SwiftData
import SwiftUI

/// Where you stand with another online user (S4 search, invite link, QR code).
enum FriendRelation: Equatable {
    case none
    /// You sent a request that is still open.
    case requested
    /// They sent you a request that is still open.
    case incoming(UUID)
    case friends
    case isMe
}

/// Friend requests and online friends (Phase 3 step 2). Holds the last state from the backend
/// so the "Requests" badge, S6 and S4 show the same thing.
@Observable
final class OnlineFriends {
    /// A pending request to you, with the sender's profile.
    struct Incoming: Identifiable, Equatable {
        let request: FriendRequest
        let profile: OnlineProfile
        var id: UUID { request.id }
    }

    let backend: any OnlineBackend
    private(set) var myUserID: String?
    private(set) var requests: [FriendRequest] = []
    private var profiles: [String: OnlineProfile] = [:]

    init(backend: any OnlineBackend) {
        self.backend = backend
    }

    /// App-wide instance, uses the same backend as the rest of the app.
    static let shared = OnlineFriends(backend: InMemoryBackend.shared)

    /// "Friend requests" in S6, newest first. Their count is the badge on the "Requests" tab.
    var incoming: [Incoming] {
        requests
            .filter { $0.toUserID == myUserID && $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
            .compactMap { request in profiles[request.fromUserID].map { Incoming(request: request, profile: $0) } }
    }

    func relation(to userID: String) -> FriendRelation {
        Self.relation(to: userID, me: myUserID, requests: requests)
    }

    static func relation(to userID: String, me: String?, requests: [FriendRequest]) -> FriendRelation {
        guard let me else { return .none }
        if userID == me { return .isMe }
        let between = requests.filter {
            ($0.fromUserID == me && $0.toUserID == userID) || ($0.fromUserID == userID && $0.toUserID == me)
        }
        if between.contains(where: { $0.status == .accepted }) { return .friends }
        if let theirs = between.first(where: { $0.fromUserID == userID && $0.status == .pending }) {
            return .incoming(theirs.id)
        }
        if between.contains(where: { $0.fromUserID == me && $0.status == .pending }) { return .requested }
        return .none
    }

    /// User IDs of everyone with an accepted request in either direction.
    static func friendUserIDs(me: String, requests: [FriendRequest]) -> Set<String> {
        Set(requests.filter { $0.status == .accepted }.compactMap { request in
            if request.fromUserID == me { return request.toUserID }
            if request.toUserID == me { return request.fromUserID }
            return nil
        })
    }

    // MARK: - Actions

    /// Loads requests and profiles, and makes sure every online friend exists as a local player.
    /// Does nothing before you have chosen a username.
    func refresh(me: Player, context: ModelContext) async throws {
        guard let myUserID = me.cloudUserID else { return }
        self.myUserID = myUserID
        requests = try await backend.friendRequests()

        let needed = Set(requests.filter { $0.status != .declined }.flatMap { [$0.fromUserID, $0.toUserID] })
            .subtracting([myUserID])
        for userID in needed {
            if let profile = try await backend.fetchProfile(userID: userID) { profiles[userID] = profile }
        }
        for userID in Self.friendUserIDs(me: myUserID, requests: requests) {
            if let profile = profiles[userID] { Self.upsertPlayer(profile, in: context) }
        }
    }

    /// "Add" in S4: sends a request, or accepts theirs if they already asked you.
    func add(_ profile: OnlineProfile, me: Player, context: ModelContext) async throws {
        guard me.cloudUserID != nil else { return }
        switch relation(to: profile.userID) {
        case .none:
            profiles[profile.userID] = profile
            _ = try await backend.sendFriendRequest(to: profile.userID)
        case .incoming(let requestID):
            try await backend.respond(to: requestID, accept: true)
        case .requested, .friends, .isMe:
            return
        }
        try await refresh(me: me, context: context)
    }

    func accept(_ incoming: Incoming, me: Player, context: ModelContext) async throws {
        try await backend.respond(to: incoming.request.id, accept: true)
        try await refresh(me: me, context: context)
    }

    func decline(_ incoming: Incoming, me: Player, context: ModelContext) async throws {
        try await backend.respond(to: incoming.request.id, accept: false)
        try await refresh(me: me, context: context)
    }

    /// The local player for an online friend: created on the first sync, then kept up to date
    /// with name, color, photo and username.
    @discardableResult
    static func upsertPlayer(_ profile: OnlineProfile, in context: ModelContext) -> Player {
        let players = (try? context.fetch(FetchDescriptor<Player>())) ?? []
        if let player = players.first(where: { $0.cloudUserID == profile.userID && !$0.isMe }) {
            player.name = profile.name
            player.colorHex = profile.colorHex
            player.photo = profile.photo
            player.username = profile.username
            return player
        }
        let player = Player(name: profile.name, photo: profile.photo, colorHex: profile.colorHex,
                            cloudUserID: profile.userID, username: profile.username)
        context.insert(player)
        return player
    }
}

extension EnvironmentValues {
    /// Friend requests and online friends (Phase 3).
    @Entry var onlineFriends: OnlineFriends = OnlineFriends.shared
}
