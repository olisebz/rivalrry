import SwiftUI

/// One friend on S1 (design.md §6.2).
struct FriendCard: View {
    let summary: FriendSummary

    var body: some View {
        HStack(spacing: Spacing.m) {
            AvatarView(player: summary.friend)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(summary.friend.shortName)
                    .font(.headline)
                    .foregroundStyle(Color.rvTextPrimary)
                if let lastMatchText {
                    Text(lastMatchText)
                        .font(.subheadline)
                        .foregroundStyle(Color.rvTextSecondary)
                }
            }

            Spacer(minLength: Spacing.s)

            RecordText(record: summary.record, font: .rvScoreLarge)
        }
        .padding(Spacing.m)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// "Last match: Badminton · 2 days ago"
    /// Non-breaking spaces keep each part together, so a long line only wraps after "Last match:" or "·".
    private var lastMatchText: String? {
        guard let match = summary.lastMatch else { return nil }
        let sport = match.customSport?.name ?? match.sportType.displayName
        let keepTogether = { (text: String) in text.replacingOccurrences(of: " ", with: "\u{00A0}") }
        return "Last\u{00A0}match: \(keepTogether(sport))\u{00A0}· \(keepTogether(RelativeDay.text(for: match.date)))"
    }
}
