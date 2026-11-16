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

/// "12 – 9" from your point of view. Your number is green when you lead,
/// everything is grey when tied, and normal text color when the friend leads (design.md §2.3).
struct RecordText: View {
    let record: Record
    let font: Font

    var body: some View {
        HStack(spacing: 0) {
            Text("\(record.wins)")
                .foregroundStyle(record.leader == .me ? Color.rvAccent : baseColor)
            Text(rest)
                .foregroundStyle(baseColor)
        }
        .font(font)
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var baseColor: Color {
        record.leader == .tied ? .rvTextSecondary : .rvTextPrimary
    }

    /// Draws are only shown when there are any: "12 – 9 – 1".
    private var rest: String {
        record.draws > 0 ? " – \(record.losses) – \(record.draws)" : " – \(record.losses)"
    }

    private var accessibilityText: String {
        var text = "\(record.wins) wins, \(record.losses) losses"
        if record.draws > 0 { text += ", \(record.draws) draws" }
        return text
    }
}
