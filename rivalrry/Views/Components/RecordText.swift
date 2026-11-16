import SwiftUI

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
