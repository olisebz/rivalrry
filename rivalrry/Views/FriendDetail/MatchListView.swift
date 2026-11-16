import SwiftUI
import SwiftData

/// "See all": every match with this friend, filterable by sport (plan.md §4 S2a).
struct MatchListView: View {
    let me: Player
    let friend: Player
    @Query private var allMatches: [Match]
    @State private var sport: SportType?

    var body: some View {
        let sports = Rivalry.sportsPlayed(of: me, with: friend, in: allMatches)
        let matches = Rivalry.matches(of: me, with: friend, in: allMatches, sport: sport)

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                if sports.count > 1 {
                    FilterChips(options: [(value: SportType?.none, title: "All")]
                                    + sports.map { (value: SportType?.some($0), title: $0.displayName) },
                                selection: $sport)
                }
                MatchRows(matches: matches, me: me)
                    .padding(.horizontal, Spacing.m)
            }
            .padding(.top, Spacing.s)
        }
        .background(Color.rvBackground)
        .navigationTitle("Matches")
        .navigationBarTitleDisplayMode(.inline)
    }
}
