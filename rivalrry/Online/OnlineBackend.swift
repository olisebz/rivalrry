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
}

/// Backend that keeps everything in memory. Used for tests and previews, and in the app
/// until CloudKit is wired up.
final class InMemoryBackend: OnlineBackend {
    private let userID: String?
    private(set) var profiles: [String: OnlineProfile] = [:]
    private(set) var requests: [FriendRequest] = []
    /// Users that accept your requests right away (debug test users).
    private let autoAccepting: Set<String>

    /// `userID == nil` simulates a device without an iCloud account.
    init(userID: String? = "local-user", profiles: [OnlineProfile] = [],
         requests: [FriendRequest] = [], autoAccepting: Set<String> = []) {
        self.userID = userID
        for profile in profiles { self.profiles[profile.userID] = profile }
        self.requests = requests
        self.autoAccepting = autoAccepting
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

    /// Debug only: the sample players (design.md §9.4) as online users, so search and requests can
    /// be tried in the simulator. Max, Tom and Lukas accept requests right away; Jonas sends you one.
    static func withTestUsers(userID: String = "local-user") -> InMemoryBackend {
        let users = [
            OnlineProfile(userID: "test-max", username: "max_keller", name: "Max Keller", colorHex: "4F6BED"),
            OnlineProfile(userID: "test-tom", username: "tom_berger", name: "Tom Berger", colorHex: "E8590C"),
            OnlineProfile(userID: "test-lukas", username: "lukas_huber", name: "Lukas Huber", colorHex: "7C3AED"),
            OnlineProfile(userID: "test-jonas", username: "jonas_weber", name: "Jonas Weber", colorHex: "0CA678"),
        ]
        return InMemoryBackend(
            userID: userID, profiles: users,
            requests: [FriendRequest(fromUserID: "test-jonas", toUserID: userID)],
            autoAccepting: ["test-max", "test-tom", "test-lukas"])
    }
}
