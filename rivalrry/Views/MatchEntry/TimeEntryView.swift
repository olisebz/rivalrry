import SwiftUI

/// `time` entry (Running 1v1): distance, then a time or DNF per player.
struct TimeEntryView: View {
    @Binding var draft: MatchDraft
    let friendName: String
    /// "You", or the team name in `Team` mode.
    var myName = "You"
    /// Players that can join as extra runners. With 3+ runners the run becomes a `Race`.
    var available: [Player] = []
    @State private var isCustomDistance = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Distance")
                    .font(.subheadline)
                    .foregroundStyle(Color.rvTextSecondary)
                Picker("Distance", selection: distanceChoice) {
                    ForEach(ResultRules.runningDistances, id: \.self) {
                        Text(TimeText.distance($0)).tag(Optional($0))
                    }
                    Text("Custom").tag(Int?.none)
                }
                .pickerStyle(.menu)
                .tint(Color.rvTextPrimary)

                if isCustomDistance {
                    TextField("Meters", value: $draft.distanceMeters, format: .number)
                        .keyboardType(.numberPad)
                        .padding(Spacing.m)
                        .background(Color.rvSurface,
                                    in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                }
            }

            runner(myName, time: $draft.timeTextA, dnf: $draft.dnfA)
            runner(friendName, time: $draft.timeTextB, dnf: $draft.dnfB)

            // 3+ runners = race; places come from the times (plan.md §2.2).
            ForEach($draft.extraRunners) { $extra in
                runner(extra.player.shortName, time: $extra.timeText, dnf: $extra.dnf) {
                    withAnimation(.spring(duration: 0.3)) {
                        draft.extraRunners.removeAll { $0.id == extra.id }
                    }
                }
            }
            if 2 + draft.extraRunners.count < 12 {
                AddPlayerMenu(title: "Add Runner", available: available) { player in
                    withAnimation(.spring(duration: 0.3)) { draft.extraRunners.append(RaceEntry(player: player)) }
                }
            }
        }
        .onAppear {
            // Editing a run with e.g. 1500 m: show it as "Custom", not as an empty menu.
            if let distance = draft.distanceMeters, !ResultRules.runningDistances.contains(distance) {
                isCustomDistance = true
            }
        }
    }

    /// `nil` selects "Custom".
    private var distanceChoice: Binding<Int?> {
        Binding(
            get: { isCustomDistance ? nil : draft.distanceMeters },
            set: { value in
                isCustomDistance = value == nil
                draft.distanceMeters = value
            }
        )
    }

    private func runner(_ name: String, time: Binding<String>, dnf: Binding<Bool>,
                        onRemove: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rvTextPrimary)
                Spacer()
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.rvTextSecondary)
                            .frame(width: 44, height: 32)
                    }
                    .accessibilityLabel("Remove \(name)")
                }
            }
            HStack(spacing: Spacing.m) {
                TextField("0:00.00", text: time)
                    .keyboardType(.numbersAndPunctuation)
                    .font(.rvScoreLarge)
                    .disabled(dnf.wrappedValue)
                    .opacity(dnf.wrappedValue ? 0.4 : 1)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(Color.rvSurface,
                                in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                    .accessibilityLabel("\(name), time")
                Toggle("DNF", isOn: dnf)
                    .fixedSize()
                    .tint(Color.rvAccent)
            }
        }
    }
}
