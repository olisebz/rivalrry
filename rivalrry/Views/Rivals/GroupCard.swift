import SwiftUI

/// One group in the S1 section "Groups" (plan.md §4 S1), styled like the friend card (design.md §6.2).
struct GroupCard: View {
    let group: PlayerGroup

    var body: some View {
        HStack(spacing: Spacing.m) {
            // The group's symbol where friends have their avatar (decision 4: no emojis).
            Image(systemName: group.symbolName)
                .font(.headline)
                .foregroundStyle(Color.rvTextPrimary)
                .frame(width: 40, height: 40)
                .background(Color.rvBackground, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(group.name)
                    .font(.headline)
                    .foregroundStyle(Color.rvTextPrimary)
                Text(group.memberCountText)
                    .font(.subheadline)
                    .foregroundStyle(Color.rvTextSecondary)
            }

            Spacer(minLength: Spacing.s)
        }
        .padding(Spacing.m)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
