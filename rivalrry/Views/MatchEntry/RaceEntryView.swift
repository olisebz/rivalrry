import SwiftUI

/// `placement` entry (Go-Kart): drag racers into finishing order, places on the left (plan.md §4 S2b).
/// Optional fastest lap per racer and "DNF" (always last place).
struct RaceEntryView: View {
    @Binding var draft: MatchDraft
    /// The friend the match is added for; like you, always part of the race.
    let friend: Player
    /// Players that can still be added.
    let available: [Player]

    private let rowHeight: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Drag to set the finishing order.")
                .font(.subheadline)
                .foregroundStyle(Color.rvTextSecondary)

            // A List for drag & drop; fixed height so it scrolls with the page.
            List {
                ForEach($draft.racers) { $racer in
                    row($racer)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: Spacing.s))
                        .listRowBackground(Color.rvSurface)
                }
                .onMove { from, to in
                    draft.racers.move(fromOffsets: from, toOffset: to)
                    draft.sortDNFLast()
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))
            .scrollDisabled(true)
            .frame(height: CGFloat(draft.racers.count) * rowHeight)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))

            if draft.racers.count < 12 {
                AddPlayerMenu(title: "Add Racer", available: available) { player in
                    withAnimation(.spring(duration: 0.3)) {
                        draft.racers.append(RaceEntry(player: player))
                        draft.sortDNFLast()
                    }
                }
            }
        }
    }

    private func row(_ racer: Binding<RaceEntry>) -> some View {
        let place = placeText(for: racer.wrappedValue)
        let isRemovable = !racer.wrappedValue.player.isMe && racer.wrappedValue.id != friend.id

        return HStack(spacing: Spacing.s) {
            Text(place)
                .font(.headline.monospacedDigit())
                .foregroundStyle(racer.wrappedValue.dnf ? Color.rvTextTertiary : Color.rvTextPrimary)
                .lineLimit(1)
                .fixedSize()
                .frame(width: 44)
            AvatarView(player: racer.wrappedValue.player, size: 32)
            Text(racer.wrappedValue.player.isMe ? "You" : racer.wrappedValue.player.shortName)
                .font(.body)
                .foregroundStyle(Color.rvTextPrimary)
                .lineLimit(1)
            Spacer(minLength: Spacing.xs)
            // Fastest lap only for Go-Kart, not for custom placement sports.
            if draft.sport.usesLaps {
                TextField("Best lap", text: racer.lapText)
                    .keyboardType(.numbersAndPunctuation)
                    .font(.subheadline.monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .disabled(racer.wrappedValue.dnf)
            }
            Toggle("DNF", isOn: Binding(
                get: { racer.wrappedValue.dnf },
                set: { value in
                    withAnimation(.spring(duration: 0.3)) {
                        racer.wrappedValue.dnf = value
                        draft.sortDNFLast()
                    }
                }))
                .toggleStyle(.button)
                .font(.caption.weight(.semibold))
                .tint(Color.rvTextSecondary)
            if isRemovable {
                Button {
                    withAnimation(.spring(duration: 0.3)) { draft.racers.removeAll { $0.id == racer.wrappedValue.id } }
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.rvTextSecondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(racer.wrappedValue.player.shortName)")
            }
        }
        .frame(height: rowHeight)
    }

    /// "1", "2" … for finishers, "DNF" for the rest.
    private func placeText(for racer: RaceEntry) -> String {
        guard !racer.dnf, let index = draft.racers.firstIndex(where: { $0.id == racer.id }) else { return "DNF" }
        return "\(draft.racers[..<index].filter { !$0.dnf }.count + 1)"
    }
}

/// "Add Player" / "Add Racer" / "Add Runner" menu with the available friends.
struct AddPlayerMenu: View {
    let title: String
    let available: [Player]
    let add: (Player) -> Void

    var body: some View {
        Menu {
            if available.isEmpty { Text("Add friends first") }
            ForEach(available) { player in
                Button(player.name) { add(player) }
            }
        } label: {
            Label(title, systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.rvTextPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
    }
}
