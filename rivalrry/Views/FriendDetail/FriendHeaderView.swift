import SwiftUI

/// S2 header: you vs. friend, the record and a bar showing who leads (design.md §6.3).
struct FriendHeaderView: View {
    let me: Player?
    let friend: Player
    let record: Record

    var body: some View {
        VStack(spacing: Spacing.l) {
            HStack(alignment: .top) {
                person(name: me?.name ?? "You", colorHex: me?.colorHex ?? "6E6E73",
                       photo: me?.photo, label: "You")
                Spacer()
                person(name: friend.name, colorHex: friend.colorHex,
                       photo: friend.photo, label: friend.shortName)
            }
            .padding(.horizontal, Spacing.xl)

            RecordText(record: record, font: .rvScoreHero)
                .contentTransition(.numericText())

            WinShareBar(share: record.winShare)
                .padding(.horizontal, Spacing.xl)
        }
        .padding(.top, Spacing.s)
        .padding(.bottom, Spacing.m)
    }

    private func person(name: String, colorHex: String, photo: Data?, label: String) -> some View {
        VStack(spacing: Spacing.s) {
            AvatarView(name: name, colorHex: colorHex, photo: photo, size: 64)
            Text(label)
                .font(.headline)
                .foregroundStyle(Color.rvTextPrimary)
                .lineLimit(1)
        }
        .frame(minWidth: 88)
    }
}

/// 6 pt capsule: your share of wins in green, the rest grey. All grey without decided duels.
struct WinShareBar: View {
    let share: Double?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.rvSeparator)
                if let share, share > 0 {
                    Capsule()
                        .fill(Color.rvAccent)
                        .frame(width: geometry.size.width * share)
                }
            }
        }
        .frame(height: 6)
        .animation(.spring(duration: 0.3), value: share)
        .accessibilityHidden(true)
    }
}
