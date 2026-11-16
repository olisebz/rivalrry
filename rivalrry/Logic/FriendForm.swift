import Foundation
import SwiftData

/// S4 Add Friend / Edit Friend rules (plan.md §4 S4).
enum FriendForm {
    static let nameLimit = 20

    /// Avatar colors to pick from. No red (only for deleting) and no accent green (design.md §2).
    static let colors = ["4F6BED", "E8590C", "7C3AED", "D6336C", "0CA678", "F59F00", "1098AD", "6E6E73"]

    enum NameIssue: Equatable {
        case empty, tooLong, notUnique

        var message: String {
            switch self {
            case .empty: "Enter a name."
            case .tooLong: "A name can have up to \(FriendForm.nameLimit) characters."
            case .notUnique: "You already have a friend with this name."
            }
        }
    }

    static func cleaned(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Name: required, 1–20 characters, unique (case-insensitive) among all players except `editing`.
    static func validateName(_ name: String, existing: [Player], editing: Player? = nil) -> NameIssue? {
        let trimmed = cleaned(name)
        if trimmed.isEmpty { return .empty }
        if trimmed.count > nameLimit { return .tooLong }
        let taken = existing.contains {
            $0.id != editing?.id && cleaned($0.name).caseInsensitiveCompare(trimmed) == .orderedSame
        }
        return taken ? .notUnique : nil
    }
}

extension Player {
    /// Your own player. Created as "You" if missing; onboarding (S0) renames it instead of creating a second one.
    @discardableResult
    static func ensureMe(in context: ModelContext) -> Player {
        let players = (try? context.fetch(FetchDescriptor<Player>())) ?? []
        if let me = players.first(where: \.isMe) { return me }
        let me = Player(name: "You", isMe: true)
        context.insert(me)
        return me
    }
}
