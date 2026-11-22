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

enum OnlineError: Error, Equatable {
    /// Someone else already has this username.
    case usernameTaken
    /// No iCloud account on this device.
    case noAccount
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
}

/// Backend that keeps everything in memory. Used for tests and previews, and in the app
/// until CloudKit is wired up.
final class InMemoryBackend: OnlineBackend {
    private let userID: String?
    private(set) var profiles: [String: OnlineProfile] = [:]

    /// `userID == nil` simulates a device without an iCloud account.
    init(userID: String? = "local-user", profiles: [OnlineProfile] = []) {
        self.userID = userID
        for profile in profiles { self.profiles[profile.userID] = profile }
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
}

extension EnvironmentValues {
    /// The backend for all online features (Phase 3).
    @Entry var onlineBackend: any OnlineBackend = InMemoryBackend.shared
}

extension InMemoryBackend {
    /// App-wide instance while there is no CloudKit.
    static let shared = InMemoryBackend()
}
