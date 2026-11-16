import SwiftUI

/// `penalties` entry: shots per side, then one circle per shot. Tap the next circle to enter a goal,
/// tap again for a miss. Sudden death rounds appear automatically while it's tied.
struct PenaltiesEntryView: View {
    @Binding var draft: MatchDraft
    let friendName: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Picker("Shots per side", selection: $draft.penaltyShotsPerSide) {
                ForEach(ResultRules.penaltyShotOptions, id: \.self) { Text("\($0) shots").tag($0) }
            }
            .pickerStyle(.segmented)

            HStack(alignment: .top, spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    name("You")
                    name(friendName)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    Grid(horizontalSpacing: Spacing.xs, verticalSpacing: Spacing.s) {
                        GridRow { circles(for: .a) }
                        GridRow { circles(for: .b) }
                    }
                }
            }

            if draft.penaltyRounds > draft.penaltyShotsPerSide {
                Text("Sudden Death")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rvTextSecondary)
            }
        }
    }

    private func name(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.rvTextPrimary)
            .lineLimit(1)
            .frame(width: 64, height: 44, alignment: .leading)
    }

    @ViewBuilder
    private func circles(for side: Side) -> some View {
        ForEach(0..<draft.penaltyRounds, id: \.self) { round in
            let state = draft.shotState(round: round, side: side)
            Button {
                withAnimation(.spring(duration: 0.3)) { draft.tapShot(round: round, side: side) }
            } label: {
                ShotCircle(state: state)
            }
            .buttonStyle(.plain)
            .disabled(state == .empty)
            .accessibilityLabel(accessibilityText(state, round: round, side: side))
        }
    }

    private func accessibilityText(_ state: MatchDraft.ShotState, round: Int, side: Side) -> String {
        let who = side == .a ? "You" : friendName
        let what = switch state {
        case .scored: "goal"
        case .missed: "miss"
        case .next, .empty: "not taken"
        }
        return "\(who), shot \(round + 1), \(what)"
    }
}

/// One shot: goal = green with checkmark, miss = grey with xmark (design.md §2.2, §5).
struct ShotCircle: View {
    let state: MatchDraft.ShotState

    var body: some View {
        ZStack {
            switch state {
            case .scored:
                Circle().fill(Color.rvAccent)
                Image(systemName: "checkmark").foregroundStyle(Color.rvOnAccent)
            case .missed:
                Circle().fill(Color.rvSurface)
                Image(systemName: "xmark").foregroundStyle(Color.rvTextSecondary)
            case .next:
                Circle().strokeBorder(Color.rvTextPrimary, lineWidth: 2)
            case .empty:
                Circle().fill(Color.rvSurface)
            }
        }
        .font(.subheadline.weight(.bold))
        .frame(width: 36, height: 36)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
}
