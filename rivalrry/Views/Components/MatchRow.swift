import SwiftUI

/// One match in a list (design.md §6.9), seen from `me`.
struct MatchRow: View {
    let match: Match
    let me: Player
    /// Group lists (S8) also say who you played.
    var showsOpponents = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
            Image(systemName: match.sport.symbolName)
                .font(.body)
                .foregroundStyle(Color.rvTextPrimary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(match.sport.displayName)
                    .font(.body)
                    .foregroundStyle(Color.rvTextPrimary)
                Text(showsOpponents ? match.groupDetailText(for: me) : match.detailText())
                    .font(.subheadline)
                    .foregroundStyle(Color.rvTextSecondary)
            }

            Spacer(minLength: Spacing.s)

            Text(match.scoreText(for: me))
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(match.outcome(for: me) == .win ? Color.rvAccent : Color.rvTextPrimary)

            if let statusSymbol {
                Image(systemName: statusSymbol)
                    .font(.footnote)
                    .foregroundStyle(Color.rvTextSecondary)
            }
        }
        .padding(.vertical, Spacing.s + Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Local matches (Phase 1–2) have no confirmation, so no symbol.
    private var statusSymbol: String? {
        switch match.status {
        case .confirmed: "checkmark"
        case .pending: "clock"
        case .local, .rejected: nil
        }
    }
}
