import SwiftUI

/// One online user: avatar, name, @username and an optional trailing control.
/// Used in the S4 search results and in S6 "Friend requests".
struct OnlineProfileRow<Trailing: View>: View {
    let profile: OnlineProfile
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Spacing.m) {
            AvatarView(name: profile.name, colorHex: profile.colorHex, photo: profile.photo, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.rvTextPrimary)
                    .lineLimit(1)
                Text("@\(profile.username)")
                    .font(.subheadline)
                    .foregroundStyle(Color.rvTextSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.s)
            trailing()
        }
        .padding(.vertical, Spacing.xs)
    }
}

/// Small grey capsule button in rows ("Add", "Accept"). Neutral, so a list of requests
/// doesn't fill up with green (design.md §1).
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.rvTextPrimary)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: 32)
            .background(Color.rvSurface, in: Capsule())
            // Whole capsule plus margin is at least 44 pt tall to tap.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.3), value: configuration.isPressed)
    }
}

/// The trailing control for a search result, depending on where you stand with that user.
struct RelationControl: View {
    let relation: FriendRelation
    let onAdd: () -> Void

    var body: some View {
        switch relation {
        case .none:
            Button("Add", action: onAdd).buttonStyle(PillButtonStyle())
        case .incoming:
            Button("Accept", action: onAdd).buttonStyle(PillButtonStyle())
        case .requested:
            status("Requested")
        case .friends:
            status("Friends")
        case .isMe:
            status("You")
        }
    }

    private func status(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color.rvTextSecondary)
    }
}
