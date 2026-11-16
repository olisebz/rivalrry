import SwiftUI

/// `fight` entry: winner or "Draw", method of victory, rounds and the round it ended.
struct FightEntryView: View {
    @Binding var draft: MatchDraft
    let friendName: String
    /// "You", or the team name in `Team` mode.
    var myName = "You"

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            section("Winner") {
                Picker("Winner", selection: $draft.fightWinner) {
                    Text(myName).tag(Side?.some(.a))
                    Text(friendName).tag(Side?.some(.b))
                    Text("Draw").tag(Side?.none)
                }
                .pickerStyle(.segmented)
            }

            section("Method") {
                Picker("Method", selection: $draft.fightMethod.animation(.spring(duration: 0.3))) {
                    ForEach(FightMethod.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            HStack(alignment: .top) {
                section("Rounds") {
                    ScoreStepper(value: $draft.fightRounds, range: ResultRules.fightRounds, label: "Rounds")
                }
                Spacer()
                if draft.fightMethod != .points {
                    section("Ended in round") {
                        ScoreStepper(value: $draft.fightEndRound, range: 1...max(1, draft.fightRounds),
                                     label: "Ended in round")
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.rvTextSecondary)
            content()
        }
    }
}
