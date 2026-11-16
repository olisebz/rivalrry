import SwiftUI

/// `points` entry: two large counters (Football, Basketball).
struct PointsEntryView: View {
    @Binding var draft: MatchDraft
    let friendName: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            counter(title: "You", value: $draft.scoreA)
            counter(title: friendName, value: $draft.scoreB)
        }
    }

    private func counter(title: String, value: Binding<Int>) -> some View {
        VStack(spacing: Spacing.s) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.rvTextPrimary)
                .lineLimit(1)
            ScoreStepper(value: value, range: 0...999, label: title)
        }
        .frame(maxWidth: .infinity)
    }
}
