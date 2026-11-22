import SwiftUI
import SwiftData

/// S9 – Profile & Settings (plan.md §4 S9): profile with username (Phase 3), own stats, "Sports", "Reset All Data".
struct ProfileView: View {
    @Query private var players: [Player]
    @Query private var matches: [Match]
    @Query(sort: \CustomSport.name) private var customSports: [CustomSport]
    @Environment(\.modelContext) private var context

    @AppStorage(SportSettings.hiddenKey) private var hiddenRaw = ""
    @AppStorage(SportSettings.hiddenCustomKey) private var hiddenCustomRaw = ""
    @AppStorage(SportSettings.onboardedKey) private var isOnboarded = false

    @State private var isEditingProfile = false
    @State private var isEditingUsername = false
    @State private var isConfirmingReset = false
    @State private var isConfirmingResetAgain = false
    @State private var isCreatingSport = false
    @State private var editedSport: CustomSport?

    private var me: Player? { players.first(where: \.isMe) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    if let me {
                        profileHeader(me)
                        stats(Rivalry.profileStats(of: me, in: matches))
                        EloTableSection(entries: Elo.table(for: matches).entries(of: me))
                    }
                    sportsSection
                    resetButton
                }
                .padding(Spacing.m)
            }
            .background(Color.rvBackground)
            .navigationTitle("Profile")
            .navigationDestination(for: EloEntry.self) { entry in
                if let me { EloDetailView(entry: entry, me: me) }
            }
            .sheet(isPresented: $isEditingProfile) {
                if let me { FriendFormView(friend: me) }
            }
            .sheet(isPresented: $isEditingUsername) {
                if let me { UsernameFormView(me: me) }
            }
            .sheet(isPresented: $isCreatingSport) { CustomSportFormView() }
            .sheet(item: $editedSport) { CustomSportFormView(sport: $0) }
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
                // Online username (Phase 3); tap to choose or change it.
                Button(me.username.map { "@\($0)" } ?? "Choose Username") { isEditingUsername = true }
                    .font(.subheadline)
                    .foregroundStyle(Color.rvTextSecondary)
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
                    SportSettingRow(sport: Sport(sport), isShown: shownBinding(sport))
                    Rectangle().fill(Color.rvSeparator).frame(height: 0.5)
                        .padding(.leading, 28 + Spacing.m)
                }
                // Custom sports (Phase 2): tap the name to edit or delete.
                ForEach(customSports) { custom in
                    SportSettingRow(sport: Sport(custom), isShown: shownBinding(custom)) {
                        editedSport = custom
                    }
                    Rectangle().fill(Color.rvSeparator).frame(height: 0.5)
                        .padding(.leading, 28 + Spacing.m)
                }
                Button {
                    isCreatingSport = true
                } label: {
                    HStack(spacing: Spacing.m) {
                        Image(systemName: "plus")
                            .frame(width: 28)
                        Text("New Sport")
                        Spacer()
                    }
                    .font(.body)
                    .foregroundStyle(Color.rvTextPrimary)
                    .padding(.vertical, Spacing.s + Spacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Visible sports in "Add Match", built-in and custom.
    private var visibleCount: Int {
        let hiddenCustom = SportSettings.decodeIDs(hiddenCustomRaw)
        return SportType.phase1Sports.count - SportSettings.decode(hiddenRaw).count
            + customSports.filter { !hiddenCustom.contains($0.id) }.count
    }

    /// Hiding the last visible sport isn't possible: "Add Match" needs at least one.
    private func shownBinding(_ sport: SportType) -> Binding<Bool> {
        Binding(
            get: { !SportSettings.decode(hiddenRaw).contains(sport) },
            set: { shown in
                var hidden = SportSettings.decode(hiddenRaw)
                if shown {
                    hidden.removeAll { $0 == sport }
                } else if visibleCount > 1 {
                    hidden.append(sport)
                }
                hiddenRaw = SportSettings.encode(hidden)
            }
        )
    }

    private func shownBinding(_ sport: CustomSport) -> Binding<Bool> {
        Binding(
            get: { !SportSettings.decodeIDs(hiddenCustomRaw).contains(sport.id) },
            set: { shown in
                var hidden = SportSettings.decodeIDs(hiddenCustomRaw)
                if shown {
                    hidden.remove(sport.id)
                } else if visibleCount > 1 {
                    hidden.insert(sport.id)
                }
                hiddenCustomRaw = SportSettings.encodeIDs(hidden)
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
    let sport: Sport
    @Binding var isShown: Bool
    /// Custom sports: tapping the name opens "Edit Sport".
    var onEdit: (() -> Void)? = nil
    @AppStorage private var bestOf: Int

    init(sport: Sport, isShown: Binding<Bool>, onEdit: (() -> Void)? = nil) {
        self.sport = sport
        _isShown = isShown
        self.onEdit = onEdit
        // Custom sports have no S9 format setting; their key is never read.
        _bestOf = AppStorage(wrappedValue: sport.defaultBestOf ?? 0,
                             sport.builtIn.map(SportSettings.formatKey) ?? "sports.bestOf.\(sport.id)")
    }

    var body: some View {
        HStack(spacing: Spacing.m) {
            if let onEdit {
                Button(action: onEdit) {
                    HStack(spacing: Spacing.m) {
                        symbolAndName
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.rvTextTertiary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                symbolAndName
                Spacer()
            }
            if !sport.isCustom, sport.bestOfOptions.count > 1, isShown {
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

    private var symbolAndName: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: sport.symbolName)
                .foregroundStyle(Color.rvTextPrimary)
                .frame(width: 28)
            Text(sport.displayName)
                .font(.body)
                .foregroundStyle(isShown ? Color.rvTextPrimary : Color.rvTextTertiary)
        }
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
