import Foundation
import SwiftData

/// A regular group like "Padel every Thursday" (plan.md §5 `Group`, S8, Phase 4).
/// Named `PlayerGroup` because `Group` is a SwiftUI view.
///
/// Shared online with its online members (agreed with the user): local friends can be members too,
/// but only on your phone.
@Model
final class PlayerGroup {
    var id: UUID = UUID()
    var name: String = ""
    /// SF Symbol name, same picker as custom sports. Replaces the emoji from plan.md.
    var symbolName: String = "person.3"
    var createdAt: Date = Date()
    /// `true` once the group was uploaded. Groups made before you chose a username stay on your phone
    /// until then.
    var isOnline: Bool = false
    /// The online members as last known from the server (you included). Also holds members who aren't
    /// your friends, so they have no local player.
    var memberUserIDs: [String] = []

    /// Members with a local player: you, online friends and local friends.
    @Relationship(deleteRule: .nullify, inverse: \Player.groups)
    var members: [Player] = []

    init(name: String, symbolName: String = "person.3", members: [Player] = [], createdAt: Date = Date()) {
        self.name = name
        self.symbolName = symbolName
        self.members = members
        self.createdAt = createdAt
    }
}
