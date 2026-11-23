import Foundation
import SwiftUI

/// Public profile of a user, as stored online (plan.md §6.1: username, name, photo).
struct OnlineProfile: Equatable, Sendable {
    /// iCloud user record ID.
    var userID: String
    var username: String
    var name: String
    var colorHex: String
    var photo: Data?
}

/// A friend request from one user to another (plan.md §4 S4/S6). Owned by the sender;
/// the recipient's answer is stored by the backend (in CloudKit as a separate record).
struct FriendRequest: Identifiable, Equatable, Sendable {
    enum Status: String, Sendable { case pending, accepted, declined }

    var id: UUID = UUID()
    var fromUserID: String
    var toUserID: String
    var status: Status = .pending
    var createdAt: Date = Date()
}

enum OnlineError: Error, Equatable {
    /// Someone else already has this username.
    case usernameTaken
    /// No iCloud account on this device.
    case noAccount
    /// The request doesn't exist (anymore) or isn't addressed to you.
    case requestNotFound
    /// Only the creator can change or delete a match (plan.md §6.1).
    case notAllowed
}

/// Everything the app needs from the server. CloudKit (Public Database) will implement this
/// once the paid developer account is active; until then `InMemoryBackend` stands in.
protocol OnlineBackend: AnyObject {
    /// The iCloud user of this device.
    func currentUserID() async throws -> String
    /// `true` if nobody but `userID` has this (cleaned) username.
    func isUsernameAvailable(_ username: String, for userID: String) async throws -> Bool
    /// Creates or updates the profile. Throws `.usernameTaken` if another user has the username.
    func saveProfile(_ profile: OnlineProfile) async throws
    func fetchProfile(userID: String) async throws -> OnlineProfile?
    func fetchProfile(username: String) async throws -> OnlineProfile?
    /// Profiles whose username starts with `prefix`, without your own.
    func searchProfiles(prefix: String) async throws -> [OnlineProfile]

    /// Requests sent by or to you, in any status.
    func friendRequests() async throws -> [FriendRequest]
    func sendFriendRequest(to userID: String) async throws -> FriendRequest
    /// Accept or decline a pending request addressed to you.
    func respond(to requestID: UUID, accept: Bool) async throws

    /// Matches you take part in, created by anyone.
    func fetchMatches() async throws -> [MatchRecord]
    /// Creates or updates your match. Throws `.notAllowed` if someone else created it.
    func saveMatch(_ record: MatchRecord) async throws
    /// Deletes your match and its responses. Throws `.notAllowed` if someone else created it.
    func deleteMatch(id: UUID) async throws
    /// All responses to these matches, from everyone.
    func fetchResponses(matchIDs: [UUID]) async throws -> [MatchResponse]
    /// Saves your answer to a match; it replaces your earlier answer to the same match.
    func saveResponse(_ response: MatchResponse) async throws
}

/// Backend that keeps everything in memory. Used for tests and previews, and in the app
/// until CloudKit is wired up.
final class InMemoryBackend: OnlineBackend {
    private let userID: String?
    private(set) var profiles: [String: OnlineProfile] = [:]
    private(set) var requests: [FriendRequest] = []
    private(set) var matches: [UUID: MatchRecord] = [:]
    private(set) var responses: [MatchResponse] = []
    /// Users that accept your requests right away (debug test users).
    private let autoAccepting: Set<String>
    /// How users answer your matches right away (debug test users): kind and reason.
    private let autoResponses: [String: (MatchResponse.Kind, String?)]

    /// `userID == nil` simulates a device without an iCloud account.
    init(userID: String? = "local-user", profiles: [OnlineProfile] = [],
         requests: [FriendRequest] = [], autoAccepting: Set<String> = [],
         matches: [MatchRecord] = [], responses: [MatchResponse] = [],
         autoResponses: [String: (MatchResponse.Kind, String?)] = [:]) {
        self.userID = userID
        for profile in profiles { self.profiles[profile.userID] = profile }
        self.requests = requests
        self.autoAccepting = autoAccepting
        for match in matches { self.matches[match.id] = match }
        self.responses = responses
        self.autoResponses = autoResponses
    }

    func currentUserID() async throws -> String {
        guard let userID else { throw OnlineError.noAccount }
        return userID
    }

    func isUsernameAvailable(_ username: String, for userID: String) async throws -> Bool {
        !profiles.values.contains { $0.username == username && $0.userID != userID }
    }

    func saveProfile(_ profile: OnlineProfile) async throws {
        guard try await isUsernameAvailable(profile.username, for: profile.userID) else {
            throw OnlineError.usernameTaken
        }
        profiles[profile.userID] = profile
    }

    func fetchProfile(userID: String) async throws -> OnlineProfile? {
        profiles[userID]
    }

    func fetchProfile(username: String) async throws -> OnlineProfile? {
        profiles.values.first { $0.username == username }
    }

    func searchProfiles(prefix: String) async throws -> [OnlineProfile] {
        let me = try await currentUserID()
        return profiles.values
            .filter { $0.userID != me && $0.username.hasPrefix(prefix) }
            .sorted { $0.username < $1.username }
    }

    func friendRequests() async throws -> [FriendRequest] {
        let me = try await currentUserID()
        return requests.filter { $0.fromUserID == me || $0.toUserID == me }
    }

    func sendFriendRequest(to userID: String) async throws -> FriendRequest {
        var request = FriendRequest(fromUserID: try await currentUserID(), toUserID: userID)
        if autoAccepting.contains(userID) { request.status = .accepted }
        requests.append(request)
        return request
    }

    func respond(to requestID: UUID, accept: Bool) async throws {
        let me = try await currentUserID()
        guard let index = requests.firstIndex(where: {
            $0.id == requestID && $0.toUserID == me && $0.status == .pending
        }) else { throw OnlineError.requestNotFound }
        requests[index].status = accept ? .accepted : .declined
    }

    func fetchMatches() async throws -> [MatchRecord] {
        let me = try await currentUserID()
        return matches.values.filter { $0.userIDs.contains(me) }.sorted { $0.date > $1.date }
    }

    func saveMatch(_ record: MatchRecord) async throws {
        let me = try await currentUserID()
        guard record.creatorUserID == me, matches[record.id].map({ $0.creatorUserID == me }) ?? true else {
            throw OnlineError.notAllowed
        }
        matches[record.id] = record
        for opponent in record.opponentUserIDs {
            guard let (kind, reason) = autoResponses[opponent] else { continue }
            store(MatchResponse(matchID: record.id, matchVersion: record.version, userID: opponent,
                                kind: kind, reason: reason))
        }
    }

    func deleteMatch(id: UUID) async throws {
        let me = try await currentUserID()
        guard let record = matches[id] else { return }
        guard record.creatorUserID == me else { throw OnlineError.notAllowed }
        matches[id] = nil
        responses.removeAll { $0.matchID == id }
    }

    func fetchResponses(matchIDs: [UUID]) async throws -> [MatchResponse] {
        responses.filter { matchIDs.contains($0.matchID) }
    }

    func saveResponse(_ response: MatchResponse) async throws {
        guard response.userID == (try await currentUserID()) else { throw OnlineError.notAllowed }
        store(response)
    }

    /// One answer per user and match.
    private func store(_ response: MatchResponse) {
        responses.removeAll { $0.matchID == response.matchID && $0.userID == response.userID }
        responses.append(response)
    }
}

extension EnvironmentValues {
    /// The backend for all online features (Phase 3).
    @Entry var onlineBackend: any OnlineBackend = InMemoryBackend.shared
}

extension InMemoryBackend {
    /// App-wide instance while there is no CloudKit.
    #if DEBUG
    static let shared = InMemoryBackend.withTestUsers()
    #else
    static let shared = InMemoryBackend()
    #endif

    /// Debug only: the sample players (design.md §9.4) as online users, so search, requests and match
    /// status can be tried in the simulator. Max, Tom and Lukas accept requests right away; Jonas sends
    /// you one and has logged a Badminton match with you. Your matches: Max confirms, Tom rejects,
    /// Lukas never answers.
    static func withTestUsers(userID: String = "local-user") -> InMemoryBackend {
        let users = [
            OnlineProfile(userID: "test-max", username: "max_keller", name: "Max Keller", colorHex: "4F6BED"),
            OnlineProfile(userID: "test-tom", username: "tom_berger", name: "Tom Berger", colorHex: "E8590C"),
            OnlineProfile(userID: "test-lukas", username: "lukas_huber", name: "Lukas Huber", colorHex: "7C3AED"),
            OnlineProfile(userID: "test-jonas", username: "jonas_weber", name: "Jonas Weber", colorHex: "0CA678"),
        ]
        let jonasMatch = MatchRecord(
            id: UUID(), creatorUserID: "test-jonas", version: 1, sportType: .badminton, mode: .oneVsOne,
            date: Date().addingTimeInterval(-86_400), bestOf: 3,
            participants: [.init(userID: "test-jonas", side: .a), .init(userID: userID, side: .b)],
            sets: [.init(index: 0, scoreA: 21, scoreB: 17), .init(index: 1, scoreA: 21, scoreB: 19)],
            createdAt: Date(), updatedAt: Date())
        return InMemoryBackend(
            userID: userID, profiles: users,
            requests: [FriendRequest(fromUserID: "test-jonas", toUserID: userID)],
            autoAccepting: ["test-max", "test-tom", "test-lukas"],
            matches: [jonasMatch],
            autoResponses: ["test-max": (.confirm, nil), "test-tom": (.reject, "It was 21–19, not 21–17")])
    }
}
