import Foundation
import SwiftData

/// Keeps your own `Player` and your online profile in sync (Phase 3 step 1).
enum ProfileSync {
    /// Checks the format, then claims the username online and stores it on `me`.
    /// Returns the issue instead of saving if the username is invalid or taken.
    @discardableResult
    static func claimUsername(_ username: String, for me: Player,
                              backend: any OnlineBackend) async throws -> Username.Issue? {
        if let issue = Username.validate(username) { return issue }
        let cleaned = Username.cleaned(username)
        let userID = try await backend.currentUserID()
        do {
            try await backend.saveProfile(profile(of: me, userID: userID, username: cleaned))
        } catch OnlineError.usernameTaken {
            return .taken
        }
        me.cloudUserID = userID
        me.username = cleaned
        return nil
    }

    /// Uploads name, color and photo after "Edit Profile". Does nothing before a username is chosen.
    /// With a `context` it goes through the `Outbox`, so it's sent later when offline.
    static func push(_ me: Player, backend: any OnlineBackend, context: ModelContext? = nil) async throws {
        guard let userID = me.cloudUserID, let username = me.username else { return }
        let profile = profile(of: me, userID: userID, username: username)
        if let context {
            try await Outbox.send(.profile(profile), backend: backend, context: context)
        } else {
            try await backend.saveProfile(profile)
        }
    }

    private static func profile(of me: Player, userID: String, username: String) -> OnlineProfile {
        OnlineProfile(userID: userID, username: username, name: me.name,
                      colorHex: me.colorHex, photo: me.photo)
    }
}
