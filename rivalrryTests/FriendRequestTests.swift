import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Phase 3 step 2: invite links, search, friend requests and online friends as local players.
struct FriendRequestTests {

    private let max = OnlineProfile(userID: "max", username: "max_keller", name: "Max Keller", colorHex: "4F6BED")
    private let tom = OnlineProfile(userID: "tom", username: "tom_berger", name: "Tom Berger", colorHex: "E8590C")

    private func setUp(requests: [FriendRequest] = [], autoAccepting: Set<String> = [])
        throws -> (OnlineFriends, InMemoryBackend, Player, ModelContext) {
        let container = try ModelContainer(for: Schema(AppSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let me = Player(name: "Alex Morgan", isMe: true, cloudUserID: "me", username: "alex")
        context.insert(me)
        let backend = InMemoryBackend(
            userID: "me",
            profiles: [OnlineProfile(userID: "me", username: "alex", name: "Alex Morgan", colorHex: "6E6E73"), max, tom],
            requests: requests, autoAccepting: autoAccepting)
        return (OnlineFriends(backend: backend), backend, me, context)
    }

    private func friends(in context: ModelContext) throws -> [Player] {
        try context.fetch(FetchDescriptor<Player>()).filter { !$0.isMe }
    }

    // MARK: - Invite link

    @Test func inviteLinkRoundTrip() {
        let url = Invite.url(for: "max_keller")
        #expect(url.absoluteString == "rivalrry://invite/max_keller")
        #expect(Invite.username(from: url) == "max_keller")
        #expect(Invite.username(from: "rivalrry://invite/Max_Keller") == "max_keller")
    }

    @Test func otherLinksAreIgnored() {
        #expect(Invite.username(from: "https://example.com/invite/max") == nil)
        #expect(Invite.username(from: "rivalrry://match/max") == nil)
        #expect(Invite.username(from: "rivalrry://invite/m") == nil)
        #expect(Invite.username(from: "rivalrry://invite/max.k") == nil)
        #expect(Invite.username(from: "hello") == nil)
    }

    @Test func qrCodeIsGenerated() {
        #expect(Invite.qrCode(for: "max_keller") != nil)
    }

    // MARK: - Search

    @Test func searchByPrefixWithoutYourself() async throws {
        let (online, _, _, _) = try setUp()
        let all = try await online.backend.searchProfiles(prefix: "")
        #expect(all.map(\.username) == ["max_keller", "tom_berger"])
        #expect(try await online.backend.searchProfiles(prefix: "to").map(\.userID) == ["tom"])
        #expect(try await online.backend.searchProfiles(prefix: "alex").isEmpty)
        #expect(try await online.backend.fetchProfile(username: "tom_berger") == tom)
    }

    // MARK: - Relation

    @Test func relations() {
        let pending = FriendRequest(fromUserID: "me", toUserID: "max")
        let incoming = FriendRequest(fromUserID: "tom", toUserID: "me")
        let accepted = FriendRequest(fromUserID: "lukas", toUserID: "me", status: .accepted)
        let declined = FriendRequest(fromUserID: "me", toUserID: "jonas", status: .declined)
        let requests = [pending, incoming, accepted, declined]

        #expect(OnlineFriends.relation(to: "max", me: "me", requests: requests) == .requested)
        #expect(OnlineFriends.relation(to: "tom", me: "me", requests: requests) == .incoming(incoming.id))
        #expect(OnlineFriends.relation(to: "lukas", me: "me", requests: requests) == .friends)
        // After a decline you can ask again.
        #expect(OnlineFriends.relation(to: "jonas", me: "me", requests: requests) == .none)
        #expect(OnlineFriends.relation(to: "me", me: "me", requests: requests) == .isMe)
        #expect(OnlineFriends.relation(to: "max", me: nil, requests: requests) == .none)
        #expect(OnlineFriends.friendUserIDs(me: "me", requests: requests) == ["lukas"])
    }

    // MARK: - Requests

    @Test func sendRequestWaitsForAccept() async throws {
        let (online, backend, me, context) = try setUp()
        try await online.add(max, me: me, context: context)

        #expect(online.relation(to: "max") == .requested)
        #expect(backend.requests.count == 1)
        // Not a friend until Max accepts.
        #expect(try friends(in: context).isEmpty)
        // Pressing "Add" again doesn't send a second request.
        try await online.add(max, me: me, context: context)
        #expect(backend.requests.count == 1)
    }

    @Test func acceptedRequestCreatesLocalFriend() async throws {
        let (online, _, me, context) = try setUp(autoAccepting: ["max"])
        try await online.add(max, me: me, context: context)

        #expect(online.relation(to: "max") == .friends)
        let friend = try #require(try friends(in: context).first)
        #expect(friend.name == "Max Keller")
        #expect(friend.username == "max_keller")
        #expect(friend.cloudUserID == "max")
        #expect(friend.colorHex == "4F6BED")
    }

    @Test func incomingRequestShowsUpAndCanBeAccepted() async throws {
        let request = FriendRequest(fromUserID: "tom", toUserID: "me")
        let (online, _, me, context) = try setUp(requests: [request])
        try await online.refresh(me: me, context: context)

        #expect(online.incoming.map(\.profile) == [tom])
        try await online.accept(try #require(online.incoming.first), me: me, context: context)

        #expect(online.incoming.isEmpty)
        #expect(online.relation(to: "tom") == .friends)
        #expect(try friends(in: context).map(\.name) == ["Tom Berger"])
    }

    @Test func declineRemovesRequestWithoutFriend() async throws {
        let request = FriendRequest(fromUserID: "tom", toUserID: "me")
        let (online, backend, me, context) = try setUp(requests: [request])
        try await online.refresh(me: me, context: context)
        try await online.decline(try #require(online.incoming.first), me: me, context: context)

        #expect(online.incoming.isEmpty)
        #expect(backend.requests.first?.status == .declined)
        #expect(try friends(in: context).isEmpty)
    }

    @Test func addingSomeoneWhoAskedYouAcceptsTheirRequest() async throws {
        let request = FriendRequest(fromUserID: "tom", toUserID: "me")
        let (online, backend, me, context) = try setUp(requests: [request])
        try await online.refresh(me: me, context: context)
        try await online.add(tom, me: me, context: context)

        #expect(backend.requests.count == 1)
        #expect(online.relation(to: "tom") == .friends)
    }

    @Test func onlyTheRecipientCanRespond() async throws {
        let outgoing = FriendRequest(fromUserID: "me", toUserID: "max")
        let (_, backend, _, _) = try setUp(requests: [outgoing])
        await #expect(throws: OnlineError.requestNotFound) {
            try await backend.respond(to: outgoing.id, accept: true)
        }
    }

    @Test func nothingHappensWithoutUsername() async throws {
        let (online, backend, _, context) = try setUp(requests: [FriendRequest(fromUserID: "tom", toUserID: "me")])
        let offlineMe = Player(name: "Alex", isMe: true)
        try await online.refresh(me: offlineMe, context: context)
        try await online.add(max, me: offlineMe, context: context)

        #expect(online.incoming.isEmpty)
        #expect(backend.requests.count == 1)
    }

    @Test func friendIsCreatedOnceAndKeptUpToDate() async throws {
        let (online, backend, me, context) = try setUp(autoAccepting: ["max"])
        try await online.add(max, me: me, context: context)

        var renamed = max
        renamed.name = "Maximilian Keller"
        try await backend.saveProfile(renamed)
        try await online.refresh(me: me, context: context)
        try await online.refresh(me: me, context: context)

        let all = try friends(in: context)
        #expect(all.count == 1)
        #expect(all.first?.name == "Maximilian Keller")
    }

    @Test func debugTestUsers() async throws {
        let backend = InMemoryBackend.withTestUsers(userID: "me")
        #expect(try await backend.searchProfiles(prefix: "").count == 4)
        #expect(try await backend.friendRequests().map(\.fromUserID) == ["test-jonas"])
        let request = try await backend.sendFriendRequest(to: "test-max")
        #expect(request.status == .accepted)
    }
}
