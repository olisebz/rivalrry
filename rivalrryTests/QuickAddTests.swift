import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Phase 2 step 6: S5 Quick Add (plan.md §4 S5).
struct QuickAddTests {

    @Test func mostRecentSportIsPreselected() throws {
        let f = try Fixture()
        let all = SportType.phase1Sports
        #expect(QuickAdd.preselectedSport(me: f.me, matches: f.matches, available: all) == nil)

        f.add(.badminton, .win, vs: [f.max])
        f.add(.football, .win, vs: [f.tom])
        #expect(QuickAdd.preselectedSport(me: f.me, matches: f.matches, available: all) == .football)

        // Pending matches don't count; hidden sports can't be preselected.
        f.add(.tennis, .win, vs: [f.max], status: .pending)
        #expect(QuickAdd.preselectedSport(me: f.me, matches: f.matches, available: all) == .football)
        #expect(QuickAdd.preselectedSport(me: f.me, matches: f.matches,
                                          available: all.filter { $0 != .football }) == .badminton)
    }

    @Test func mostRecentOpponentsFirst() throws {
        let f = try Fixture()
        f.add(.badminton, .win, vs: [f.lukas])
        f.add(.badminton, .win, vs: [f.max])
        let friends = [f.me, f.max, f.tom, f.lukas]

        let order = QuickAdd.opponents(me: f.me, friends: friends, matches: f.matches)
        #expect(order.map(\.name) == ["Max Keller", "Lukas Huber", "Tom Berger"])

        // Archived friends and you are not offered.
        f.lukas.isArchived = true
        #expect(QuickAdd.opponents(me: f.me, friends: friends, matches: f.matches).map(\.name)
            == ["Max Keller", "Tom Berger"])
    }

    @Test func friendsWithoutMatchesNewestFirst() throws {
        let f = try Fixture()
        f.tom.createdAt = Date(timeIntervalSince1970: 100)
        f.lukas.createdAt = Date(timeIntervalSince1970: 200)
        let order = QuickAdd.opponents(me: f.me, friends: [f.tom, f.lukas], matches: f.matches)
        #expect(order.map(\.name) == ["Lukas Huber", "Tom Berger"])
    }
}
