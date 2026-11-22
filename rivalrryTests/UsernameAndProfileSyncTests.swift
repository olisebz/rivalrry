import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Phase 3 step 1: username rules (plan.md §6.1) and profile sync through `OnlineBackend`.
struct UsernameAndProfileSyncTests {

    @Test func usernameFormat() {
        #expect(Username.validate("max") == nil)
        #expect(Username.validate("max_keller_99") == nil)
        #expect(Username.validate(String(repeating: "a", count: 20)) == nil)
        #expect(Username.validate("ma") == .tooShort)
        #expect(Username.validate("") == .tooShort)
        #expect(Username.validate(String(repeating: "a", count: 21)) == .tooLong)
        #expect(Username.validate("max.keller") == .invalidCharacters)
        #expect(Username.validate("max keller") == .invalidCharacters)
        #expect(Username.validate("mäx") == .invalidCharacters)
    }

    @Test func usernameIsTrimmedAndLowercased() {
        #expect(Username.cleaned("  Max_K ") == "max_k")
        #expect(Username.validate("  Max_K ") == nil)
    }

    @Test func claimUsernameSavesProfileAndPlayer() async throws {
        let backend = InMemoryBackend(userID: "me")
        let me = Player(name: "Alex", colorHex: "4F6BED", isMe: true)

        let issue = try await ProfileSync.claimUsername("Alex_1", for: me, backend: backend)

        #expect(issue == nil)
        #expect(me.username == "alex_1")
        #expect(me.cloudUserID == "me")
        let profile = try await backend.fetchProfile(userID: "me")
        #expect(profile == OnlineProfile(userID: "me", username: "alex_1", name: "Alex", colorHex: "4F6BED"))
    }

    @Test func usernameMustBeUnique() async throws {
        let backend = InMemoryBackend(userID: "me", profiles: [
            OnlineProfile(userID: "max", username: "max", name: "Max Keller", colorHex: "E8590C"),
        ])
        let me = Player(name: "Alex", isMe: true)

        // Taken by someone else, also with different case.
        #expect(try await ProfileSync.claimUsername("MAX", for: me, backend: backend) == .taken)
        #expect(me.username == nil)
        #expect(me.cloudUserID == nil)

        // Your own username can be saved again.
        #expect(try await ProfileSync.claimUsername("alex", for: me, backend: backend) == nil)
        #expect(try await ProfileSync.claimUsername("alex", for: me, backend: backend) == nil)
        #expect(try await backend.isUsernameAvailable("alex", for: "me"))
        #expect(try await !backend.isUsernameAvailable("alex", for: "max"))
    }

    @Test func invalidUsernameIsNotSent() async throws {
        let backend = InMemoryBackend(userID: "me")
        let me = Player(name: "Alex", isMe: true)
        #expect(try await ProfileSync.claimUsername("a!", for: me, backend: backend) == .tooShort)
        #expect(try await ProfileSync.claimUsername("al ex", for: me, backend: backend) == .invalidCharacters)
        #expect(backend.profiles.isEmpty)
    }

    @Test func changingUsernameFreesTheOldOne() async throws {
        let backend = InMemoryBackend(userID: "me")
        let me = Player(name: "Alex", isMe: true)
        try await ProfileSync.claimUsername("alex", for: me, backend: backend)
        try await ProfileSync.claimUsername("alex_z", for: me, backend: backend)
        #expect(me.username == "alex_z")
        #expect(try await backend.isUsernameAvailable("alex", for: "someone"))
    }

    @Test func noICloudAccount() async {
        let backend = InMemoryBackend(userID: nil)
        let me = Player(name: "Alex", isMe: true)
        await #expect(throws: OnlineError.noAccount) {
            try await ProfileSync.claimUsername("alex", for: me, backend: backend)
        }
        #expect(me.username == nil)
    }

    @Test func editProfilePushesNameColorAndPhoto() async throws {
        let backend = InMemoryBackend(userID: "me")
        let me = Player(name: "Alex", isMe: true)

        // Before a username is chosen nothing is uploaded.
        try await ProfileSync.push(me, backend: backend)
        #expect(backend.profiles.isEmpty)

        try await ProfileSync.claimUsername("alex", for: me, backend: backend)
        me.name = "Alexander"
        me.colorHex = "7C3AED"
        me.photo = Data([1, 2, 3])
        try await ProfileSync.push(me, backend: backend)

        let profile = try #require(try await backend.fetchProfile(userID: "me"))
        #expect(profile.name == "Alexander")
        #expect(profile.colorHex == "7C3AED")
        #expect(profile.photo == Data([1, 2, 3]))
        #expect(profile.username == "alex")
    }

    @Test func usernameIsStoredInSwiftData() throws {
        let container = try ModelContainer(for: Schema(AppSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let me = Player.ensureMe(in: container.mainContext)
        me.username = "alex"
        try container.mainContext.save()
        let fetched = try container.mainContext.fetch(FetchDescriptor<Player>())
        #expect(fetched.first?.username == "alex")
    }
}
