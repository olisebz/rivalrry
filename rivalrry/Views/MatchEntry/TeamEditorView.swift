import SwiftUI

/// S2b step 2 – Mode & participants (plan.md §4 S2b): "1v1" or "Team".
/// In `Team` mode you and the friend are opponents; more players come from the friends list.
/// A player can't be on both teams.
struct TeamEditorView: View {
    @Binding var draft: MatchDraft
    let me: Player?
    let friend: Player
    let players: [Player]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Picker("Mode", selection: $draft.mode.animation(.spring(duration: 0.3))) {
                Text("1v1").tag(MatchMode.oneVsOne)
                Text("Team").tag(MatchMode.team)
            }
            .pickerStyle(.segmented)

            if draft.mode == .team {
                HStack(alignment: .top, spacing: Spacing.m) {
                    column(title: "Team A", fixed: me, members: $draft.partners)
                    column(title: "Team B", fixed: friend, members: $draft.opponents)
                }
                .transition(.opacity)
            }
        }
    }

    private func column(title: String, fixed: Player?, members: Binding<[Player]>) -> some View {
        let available = draft.availablePlayers(from: players, friend: friend)
        let maxSize = draft.sport.teamSizes?.upperBound ?? 2

        return VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.rvTextSecondary)

            if let fixed { memberRow(fixed, label: fixed.isMe ? "You" : fixed.shortName, onRemove: nil) }
            ForEach(members.wrappedValue) { player in
                memberRow(player, label: player.shortName) {
                    withAnimation(.spring(duration: 0.3)) { members.wrappedValue.removeAll { $0.id == player.id } }
                }
            }

            if members.wrappedValue.count + 1 < maxSize {
                Menu {
                    if available.isEmpty {
                        Text("Add friends first")
                    }
                    ForEach(available) { player in
                        Button(player.name) {
                            withAnimation(.spring(duration: 0.3)) { members.wrappedValue.append(player) }
                        }
                    }
                } label: {
                    Label("Add Player", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rvTextPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.rvSurface,
                                    in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func memberRow(_ player: Player, label: String, onRemove: (() -> Void)?) -> some View {
        HStack(spacing: Spacing.s) {
            AvatarView(player: player, size: 32)
            Text(label)
                .font(.body)
                .foregroundStyle(Color.rvTextPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.rvTextSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Remove \(player.shortName)")
            }
        }
        .frame(minHeight: 44)
    }
}
