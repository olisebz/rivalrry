import Foundation

/// Username rules (plan.md §6.1): 3–20 characters, a–z, 0–9 and `_`, unique.
/// Uniqueness is checked by the `OnlineBackend`; this only checks the format.
enum Username {
    static let minLength = 3
    static let maxLength = 20

    enum Issue: Equatable {
        case tooShort, tooLong, invalidCharacters, taken

        var message: String {
            switch self {
            case .tooShort: "A username needs at least \(Username.minLength) characters."
            case .tooLong: "A username can have up to \(Username.maxLength) characters."
            case .invalidCharacters: "Only a–z, 0–9 and _ are allowed."
            case .taken: "This username is already taken."
            }
        }
    }

    /// Trimmed and lowercased, so "Max_K " becomes "max_k".
    static func cleaned(_ username: String) -> String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Format check on the cleaned username.
    static func validate(_ username: String) -> Issue? {
        let cleaned = cleaned(username)
        if cleaned.count < minLength { return .tooShort }
        if cleaned.count > maxLength { return .tooLong }
        let allowed = cleaned.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "_" }
        return allowed ? nil : .invalidCharacters
    }
}
