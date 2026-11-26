import SwiftUI

/// S2a Overview: "Recent Matches" with the last 5 matches and "See all" (decision 2).
struct OverviewView: View {
    let me: Player
    let friend: Player
    /// All matches with this friend, newest first.
    let matches: [Match]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent Matches")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.rvTextPrimary)
                Spacer()
                NavigationLink("See all") {
                    MatchListView(me: me, friend: friend)
                }
                .font(.headline)
                .foregroundStyle(Color.rvTextPrimary)
            }

            MatchRows(matches: Array(matches.prefix(5)), me: me)
        }
        .padding(.horizontal, Spacing.m)
    }
}

/// Match rows with separators indented to the text (design.md §6.9).
struct MatchRows: View {
    let matches: [Match]
    let me: Player
    var showsOpponents = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(matches) { match in
                NavigationLink(value: match) {
                    MatchRow(match: match, me: me, showsOpponents: showsOpponents)
                }
                .buttonStyle(.plain)
                Rectangle()
                    .fill(Color.rvSeparator)
                    .frame(height: 0.5)
                    .padding(.leading, 28 + Spacing.m)
            }
        }
    }
}
