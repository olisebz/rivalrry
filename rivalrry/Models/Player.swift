import Foundation
import SwiftData

@Model
final class Player {
    var id: UUID = UUID()
    var name: String = ""
    /// Shown inside the avatar instead of initials when set.
    @Attribute(.externalStorage) var photo: Data?
    /// Favorite color, only used for the avatar (design.md §2.4).
    var colorHex: String = "6E6E73"
    var isMe: Bool = false
    var isArchived: Bool = false
    /// Linked iCloud user (Phase 3).
    var cloudUserID: String?
    /// Online username (Phase 3, plan.md §6.1). Only set for "me" and linked friends.
    var username: String?
    var createdAt: Date = Date()

    /// All matches this player took part in. Deleting a player keeps the
    /// participant row with `player == nil` ("Deleted Player").
    @Relationship(deleteRule: .nullify, inverse: \MatchParticipant.player)
    var participations: [MatchParticipant] = []

    init(name: String, photo: Data? = nil, colorHex: String = "6E6E73",
         isMe: Bool = false, isArchived: Bool = false, cloudUserID: String? = nil,
         username: String? = nil, createdAt: Date = Date()) {
        self.name = name
        self.photo = photo
        self.colorHex = colorHex
        self.isMe = isMe
        self.isArchived = isArchived
        self.cloudUserID = cloudUserID
        self.username = username
        self.createdAt = createdAt
    }
}
