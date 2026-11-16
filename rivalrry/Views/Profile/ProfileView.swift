import SwiftUI
import SwiftData

/// S9 – Profile & Settings, Phase 1 (plan.md §4 S9): profile, own stats, "Sports", "Reset All Data".
struct ProfileView: View {
    @Query private var players: [Player]
    @Query private var matches: [Match]
    @Environment(\.modelContext) private var context

    @AppStorage(SportSettings.hiddenKey) private var hiddenRaw = ""
    @AppStorage(SportSettings.onboardedKey) private var isOnboarded = false

    @State private var isEditingProfile = false
    @State private var isConfirmingReset = false
    @State private var isConfirmingResetAgain = false

    private var me: Player? { players.first(where: \.isMe) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    if let me {
                        profileHeader(me)
                        stats(Rivalry.profileStats(of: me, in: matches))
                    }
                    sportsSection
                    resetButton
                }
                .padding(Spacing.m)
            }
            .background(Color.rvBackground)
            .navigationTitle("Profile")
            .sheet(isPresented: $isEditingProfile) {
                if let me { FriendFormView(friend: me) }
            }
            // "Reset All Data" asks twice (plan.md §4 S9).
            .confirmationDialog("Reset All Data?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
                Button("Reset All Data", role: .destructive) { isConfirmingResetAgain = true }
            } message: {
                Text("All friends, matches and settings will be deleted.")
            }
            .alert("Are you sure?", isPresented: $isConfirmingResetAgain) {
                Button("Reset All Data", role: .destructive, action: reset)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    // MARK: - Profile

    private func profileHeader(_ me: Player) -> some View {
        HStack(spacing: Spacing.m) {
            AvatarView(player: me, size: 64)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(me.name)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.rvTextPrimary)
                Button("Edit Profile") { isEditingProfile = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.rvTextSecondary)
            }
            Spacer()
        }
    }

    private func stats(_ stats: ProfileStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.s), GridItem(.flexible())], spacing: Spacing.s) {
            StatTile(title: "Matches", value: "\(stats.record.matches)")
            StatTile(title: "Win rate", value: Rivalry.percentText(stats.record.winRate))
            TextTile(title: "Favorite sport", value: stats.favoriteSport?.displayName ?? "–")
            TextTile(title: "Biggest rival", value: stats.biggestRival?.shortName ?? "–")
        }
    }

    // MARK: - Sports

    private var sportsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Sports")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.rvTextPrimary)

            VStack(spacing: 0) {
                ForEach(SportType.phase1Sports) { sport in
                    SportSettingRow(sport: sport, isShown: shownBinding(sport))
                    Rectangle().fill(Color.rvSeparator).frame(height: 0.5)
                        .padding(.leading, 28 + Spacing.m)
                }
            }
        }
    }

    /// Hiding the last visible sport isn't possible: "Add Match" needs at least one.
    private func shownBinding(_ sport: SportType) -> Binding<Bool> {
        Binding(
            get: { !SportSettings.decode(hiddenRaw).contains(sport) },
            set: { shown in
                var hidden = SportSettings.decode(hiddenRaw)
                if shown {
                    hidden.removeAll { $0 == sport }
                } else if hidden.count < SportType.phase1Sports.count - 1 {
                    hidden.append(sport)
                }
                hiddenRaw = SportSettings.encode(hidden)
            }
        )
    }

    // MARK: - Reset

    private var resetButton: some View {
        Button("Reset All Data", role: .destructive) { isConfirmingReset = true }
            .font(.headline)
            .foregroundStyle(Color.rvDestructive)
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func reset() {
        try? Rivalry.resetAllData(in: context)
        SportSettings.reset()
        // Back to onboarding.
        isOnboarded = false
    }
}

/// One sport in "Sports": show/hide and, for set sports, the default format.
private struct SportSettingRow: View {
    let sport: SportType
    @Binding var isShown: Bool
    @AppStorage private var bestOf: Int

    init(sport: SportType, isShown: Binding<Bool>) {
        self.sport = sport
        _isShown = isShown
        _bestOf = AppStorage(wrappedValue: sport.defaultBestOf ?? 0, SportSettings.formatKey(sport))
    }

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: sport.symbolName)
                .foregroundStyle(Color.rvTextPrimary)
                .frame(width: 28)
            Text(sport.displayName)
                .font(.body)
                .foregroundStyle(isShown ? Color.rvTextPrimary : Color.rvTextTertiary)
            Spacer()
            if sport.bestOfOptions.count > 1, isShown {
                Menu {
                    Picker("Format", selection: $bestOf) {
                        ForEach(sport.bestOfOptions, id: \.self) { Text("Best of \($0)").tag($0) }
                    }
                } label: {
                    Text("Best of \(bestOf)")
                        .font(.subheadline)
                        .foregroundStyle(Color.rvTextSecondary)
                }
            }
            Toggle(sport.displayName, isOn: $isShown)
                .labelsHidden()
                // Neutral: nine green toggles would break "green is rare" (design.md §1).
                .tint(Color.rvTextSecondary)
        }
        .padding(.vertical, Spacing.s)
    }
}

/// Like `StatTile`, but for a name instead of a number.
private struct TextTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.caption.weight(.medium))
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.rvTextSecondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.rvTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(Spacing.m)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

#Preview {
    ProfileView()
        .modelContainer(SampleData.container())
}
