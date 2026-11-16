import SwiftUI

/// `sets` entry: format, one row per set with steppers, tiebreak at 7:6, "Add Set", "Match not finished".
struct SetsEntryView: View {
    @Binding var draft: MatchDraft
    let friendName: String

    private let labelWidth: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if draft.sport.bestOfOptions.count > 1 {
                Picker("Format", selection: $draft.bestOf) {
                    ForEach(draft.sport.bestOfOptions, id: \.self) { Text("Best of \($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: draft.bestOf) { _, bestOf in
                    if draft.sets.count > bestOf { draft.sets.removeLast(draft.sets.count - bestOf) }
                }
            }

            HStack(spacing: 0) {
                Color.clear.frame(width: labelWidth, height: 1)
                columnTitle("You")
                columnTitle(friendName)
            }

            ForEach(draft.sets.indices, id: \.self) { index in
                setRow(index)
            }

            HStack(spacing: Spacing.s) {
                if draft.canAddSet {
                    Button("Add Set") {
                        withAnimation(.spring(duration: 0.3)) { draft.sets.append(SetEntry(scoreA: 0, scoreB: 0)) }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                if draft.sets.count > 1 {
                    Button {
                        withAnimation(.spring(duration: 0.3)) { _ = draft.sets.removeLast() }
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 44)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(width: 64)
                    .accessibilityLabel("Remove last set")
                }
            }

            Toggle("Match not finished", isOn: $draft.isRetired.animation(.spring(duration: 0.3)))
                .font(.body)
                .tint(Color.rvAccent)

            if draft.isRetired {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Who gave up?")
                        .font(.subheadline)
                        .foregroundStyle(Color.rvTextSecondary)
                    Picker("Who gave up?", selection: $draft.retiredSide) {
                        Text("You").tag(Side.a)
                        Text(friendName).tag(Side.b)
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private func columnTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.rvTextPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func setRow(_ index: Int) -> some View {
        HStack(spacing: 0) {
            Text("Set \(index + 1)")
                .font(.subheadline)
                .foregroundStyle(Color.rvTextSecondary)
                .frame(width: labelWidth, alignment: .leading)
            ScoreStepper(value: setBinding(index, \.scoreA), label: "Set \(index + 1), You")
                .frame(maxWidth: .infinity)
            ScoreStepper(value: setBinding(index, \.scoreB), label: "Set \(index + 1), \(friendName)")
                .frame(maxWidth: .infinity)
        }
        if index < draft.sets.count, draft.needsTiebreakField(draft.sets[index]) {
            HStack(spacing: 0) {
                Text("Tiebreak")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.rvTextSecondary)
                    .frame(width: labelWidth, alignment: .leading)
                ScoreStepper(value: tiebreakBinding(index, side: .a), font: .title2.weight(.semibold).monospacedDigit(),
                             label: "Tiebreak set \(index + 1), You")
                    .frame(maxWidth: .infinity)
                ScoreStepper(value: tiebreakBinding(index, side: .b), font: .title2.weight(.semibold).monospacedDigit(),
                             label: "Tiebreak set \(index + 1), \(friendName)")
                    .frame(maxWidth: .infinity)
            }
            .transition(.opacity)
        }
    }

    /// Bounds-checked binding, so removing the last set never reads a missing index.
    private func setBinding(_ index: Int, _ keyPath: WritableKeyPath<SetEntry, Int>) -> Binding<Int> {
        Binding(
            get: { index < draft.sets.count ? draft.sets[index][keyPath: keyPath] : 0 },
            set: { if index < draft.sets.count { draft.sets[index][keyPath: keyPath] = $0 } }
        )
    }

    private func tiebreakBinding(_ index: Int, side: Side) -> Binding<Int> {
        Binding(
            get: {
                guard index < draft.sets.count else { return 0 }
                return (side == .a ? draft.sets[index].tiebreakA : draft.sets[index].tiebreakB) ?? 0
            },
            set: { value in
                guard index < draft.sets.count else { return }
                // Entering one side starts the tiebreak for both.
                if side == .a {
                    draft.sets[index].tiebreakA = value
                    draft.sets[index].tiebreakB = draft.sets[index].tiebreakB ?? 0
                } else {
                    draft.sets[index].tiebreakB = value
                    draft.sets[index].tiebreakA = draft.sets[index].tiebreakA ?? 0
                }
            }
        )
    }
}
