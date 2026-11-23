import Foundation
import SwiftData
import Testing
@testable import rivalrry

/// Phase 4 step 2: "New Group" from S1 (plan.md §4 S1, S8).
struct GroupFormTests {

    private func players() throws -> (ModelContext, me: Player, max: Player, tom: Player, archived: Player) {
        let container = try ModelContainer(for: Schema(AppSchema.models),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let me = Player(name: "Alex Morgan", isMe: true)
        let max = Player(name: "Max Keller", cloudUserID: "max")
        let tom = Player(name: "Tom Berger")
        let archived = Player(name: "Anna", isArchived: true)
        for player in [me, tom, max, archived] { context.insert(player) }
        return (context, me, max, tom, archived)
    }

    @Test func issues() {
        var form = GroupForm()
        #expect(form.issue == "Enter a name.")
        form.name = "   "
        #expect(form.issue == "Enter a name.")
        form.name = String(repeating: "a", count: GroupForm.nameLimit + 1)
        #expect(form.issue == "Use at most 30 characters.")
        form.name = " Padel every Thursday "
        #expect(form.issue == "Choose at least one friend.")
        form.memberIDs = [UUID()]
        #expect(form.issue == nil)
        #expect(form.trimmedName == "Padel every Thursday")
        #expect(form.symbolName == CustomSport.symbols[0])
    }

    @Test func candidatesAreActiveFriendsByName() throws {
        let (_, me, max, tom, archived) = try players()
        let candidates = GroupForm.candidates(in: [me, tom, archived, max])
        #expect(candidates.map(\.name) == ["Max Keller", "Tom Berger"])

        var form = GroupForm()
        form.memberIDs = [tom.id, archived.id]
        #expect(form.members(from: [me, tom, archived, max]).map(\.name) == ["Tom Berger"])
    }

    @Test func memberCountIncludesOnlineMembersWhoArentFriends() throws {
        let (context, me, max, tom, _) = try players()
        me.cloudUserID = "me"
        let group = PlayerGroup(name: "Padel", members: [me, max, tom])
        context.insert(group)
        #expect(group.memberCountText == "3 members")
        group.memberUserIDs = ["me", "max", "stranger"]
        #expect(group.memberCount == 4)
        #expect(PlayerGroup(name: "Solo").memberCountText == "0 members")
    }

    @Test func groupsAreSortedByName() {
        let groups = [PlayerGroup(name: "padel"), PlayerGroup(name: "Football"), PlayerGroup(name: "Climbing")]
        #expect(PlayerGroup.sorted(groups).map(\.name) == ["Climbing", "Football", "padel"])
    }

    // MARK: - S8 (step 3)

    @Test func editFormStartsWithTheGroupAndKnowsTheChanges() throws {
        let (context, me, max, tom, archived) = try players()
        let group = PlayerGroup(name: "Padel", symbolName: "target", members: [me, max, archived])
        context.insert(group)
        var form = GroupForm(group: group)
        #expect(form.name == "Padel")
        #expect(form.symbolName == "target")
        #expect(form.memberIDs == [max.id, archived.id])
        // An archived member stays pickable while editing, so saving doesn't drop them.
        #expect(GroupForm.candidates(in: [me, max, tom, archived], group: group).map(\.name)
                == ["Anna", "Max Keller", "Tom Berger"])

        form.memberIDs = [archived.id, tom.id]
        let changes = form.memberChanges(for: group, players: [me, max, tom, archived])
        #expect(changes.added.map(\.name) == ["Tom Berger"])
        #expect(changes.removed.map(\.name) == ["Max Keller"])
    }

    @Test func membersYouFirstThenOthersAsCount() throws {
        let (context, me, max, tom, _) = try players()
        me.cloudUserID = "me"
        let group = PlayerGroup(name: "Padel", members: [tom, me, max])
        context.insert(group)
        #expect(group.sortedMembers.map(\.name) == ["Alex Morgan", "Max Keller", "Tom Berger"])
        #expect(group.otherMembersText == nil)
        group.memberUserIDs = ["me", "max", "stranger"]
        #expect(group.otherMembersText == "and 1 other")
        group.memberUserIDs = ["me", "max", "stranger", "another"]
        #expect(group.otherMembersText == "and 2 others")
    }

    @Test func groupMatchesAreThoseOnlyMembersPlayed() throws {
        let (context, me, max, tom, archived) = try players()
        let group = PlayerGroup(name: "Padel", members: [me, max, tom])
        context.insert(group)

        func badminton(against friend: Player, daysAgo: Double) -> Match {
            var draft = MatchDraft(sport: Sport(.badminton))
            draft.bestOf = 1
            draft.date = Date().addingTimeInterval(-daysAgo * 86_400)
            draft.sets = [SetEntry(scoreA: 21, scoreB: 17)]
            return draft.insertMatch(me: me, friend: friend, into: context)
        }
        let old = badminton(against: max, daysAgo: 5)
        let new = badminton(against: tom, daysAgo: 1)
        _ = badminton(against: archived, daysAgo: 2)
        let deleted = badminton(against: tom, daysAgo: 3)
        deleted.participants.first { $0.player?.id == tom.id }?.player = nil

        #expect(group.matches(in: try context.fetch(FetchDescriptor<Match>())).map(\.id) == [new.id, old.id])
    }
}
