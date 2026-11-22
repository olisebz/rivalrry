import SwiftUI

/// Custom "Win / Loss" sports: who won, or "Draw" if the sport allows it (plan.md §2.2).
struct WinLossEntryView: View {
    @Binding var draft: MatchDraft
    let friendName: String
    let myName: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Winner")
                .font(.subheadline)
                .foregroundStyle(Color.rvTextSecondary)
            Picker("Winner", selection: $draft.winner) {
                Text(myName).tag(Side?.some(.a))
                Text(friendName).tag(Side?.some(.b))
                if draft.sport.allowsDraw {
                    Text("Draw").tag(Side?.none)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
