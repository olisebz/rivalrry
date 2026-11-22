import SwiftUI

/// S2c "Head to Head" for one sport: record, then You | label | friend rows (decision 8).
/// The better value is green if it's yours, normal text if it's the friend's, grey if tied (decision 5).
struct HeadToHeadCard: View {
    let sport: Sport
    let record: Record
    let rows: [ComparisonRow]
    let friendName: String

    var body: some View {
        VStack(spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("You")
                    .font(.headline)
                    .foregroundStyle(Color.rvTextPrimary)
                Spacer()
                Text("Head to Head")
                    .font(.caption.weight(.medium))
                    .kerning(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.rvTextSecondary)
                Spacer()
                Text(friendName)
                    .font(.headline)
                    .foregroundStyle(Color.rvTextPrimary)
            }

            RecordText(record: record, font: .rvScoreLarge)
            WinShareBar(share: record.winShare)

            VStack(spacing: 0) {
                ForEach(rows, id: \.title) { row in
                    ComparisonRowView(row: row)
                    if row != rows.last {
                        Rectangle().fill(Color.rvSeparator).frame(height: 0.5)
                    }
                }
            }
        }
        .padding(Spacing.m)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

private struct ComparisonRowView: View {
    let row: ComparisonRow

    var body: some View {
        HStack {
            value(row.mine, isLeader: row.leader == .me)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.title)
                .font(.subheadline)
                .foregroundStyle(Color.rvTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            value(row.theirs, isLeader: row.leader == .friend)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, Spacing.s + Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.title): you \(row.mine), friend \(row.theirs)")
    }

    private func value(_ text: String, isLeader: Bool) -> some View {
        Text(text)
            .font(.body.weight(isLeader ? .bold : .regular).monospacedDigit())
            .foregroundStyle(color(isLeader: isLeader))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func color(isLeader: Bool) -> Color {
        switch row.leader {
        case .tied, nil: .rvTextSecondary
        case .me: isLeader ? .rvAccent : .rvTextPrimary
        case .friend: .rvTextPrimary
        }
    }
}

#Preview {
    HeadToHeadCard(
        sport: .badminton,
        record: Record(wins: 5, losses: 3),
        rows: [
            ComparisonRow(title: "Wins", mine: "5", theirs: "3", leader: .me),
            ComparisonRow(title: "Sets won", mine: "11", theirs: "8", leader: .me),
            ComparisonRow(title: "Points won", mine: "372", theirs: "381", leader: .friend),
            ComparisonRow(title: "Avg. points per set", mine: "19.6", theirs: "20.1", leader: .friend),
            ComparisonRow(title: "Set win rate", mine: "58 %", theirs: "42 %", leader: .me),
            ComparisonRow(title: "Deuce sets won", mine: "2", theirs: "2", leader: .tied),
        ],
        friendName: "Max")
        .padding(Spacing.m)
        .background(Color.rvBackground)
}
