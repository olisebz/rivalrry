import SwiftUI
import SwiftData

/// S0 – Onboarding, shown once (plan.md §4 S0):
/// 1. Welcome, 2. own profile (name, photo, color), 3. favorite sports (at least 1).
struct OnboardingView: View {
    @Query private var players: [Player]
    @Environment(\.modelContext) private var context
    @AppStorage(SportSettings.onboardedKey) private var isOnboarded = false
    @AppStorage(SportSettings.favoritesKey) private var favoritesRaw = ""

    @State private var step = 1
    @State private var name = ""
    @State private var colorHex = FriendForm.colors[0]
    @State private var photo: Data?
    @State private var favorites: [SportType] = []

    /// The placeholder "You" from before onboarding, renamed instead of duplicated.
    private var me: Player? { players.first(where: \.isMe) }

    private var nameIssue: FriendForm.NameIssue? {
        FriendForm.validateName(name, existing: players, editing: me)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case 1: welcome
                case 2: profile
                default: sports
                }
            }
            .background(Color.rvBackground)
            .toolbar {
                if step > 1 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.spring(duration: 0.3)) { step -= 1 }
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "chevron.left").fontWeight(.semibold)
                                Text("Back")
                            }
                            .padding(.horizontal, Spacing.xs)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Color.rvAccent)
        .onAppear {
            // Keep anything the placeholder already has.
            if let me, me.name != "You" {
                name = me.name
                colorHex = me.colorHex
                photo = me.photo
            }
            favorites = SportSettings.decode(favoritesRaw)
        }
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(spacing: Spacing.l) {
            Spacer()
            Text("RIVALRRY")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.rvTextPrimary)
            Text("Settle it once and for all.")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.rvTextSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Get Started") {
                withAnimation(.spring(duration: 0.3)) { step = 2 }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(Spacing.m)
    }

    private var profile: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                heading("Your profile", subtitle: "This is how you appear next to your rivals.")
                PlayerFields(name: $name, colorHex: $colorHex, photo: $photo,
                             nameIssue: nameIssue, focusesName: true, onSubmit: next)
            }
            .padding(Spacing.m)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button("Continue", action: next)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(nameIssue != nil)
                .padding(Spacing.m)
                .background(Color.rvBackground)
        }
    }

    private var sports: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                heading("Favorite sports", subtitle: "Pick at least one. They come first when you add a match.")
                    .padding(.horizontal, Spacing.m)
                SportGridView(sports: Sport.builtInSports,
                              isSelected: { $0.builtIn.map(favorites.contains) ?? false },
                              toggle: { selected in
                                  guard let sport = selected.builtIn else { return }
                                  if let index = favorites.firstIndex(of: sport) {
                                      favorites.remove(at: index)
                                  } else {
                                      favorites.append(sport)
                                  }
                              })
            }
            .padding(.vertical, Spacing.m)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Done", action: finish)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(favorites.isEmpty)
                .padding(Spacing.m)
                .background(Color.rvBackground)
        }
    }

    private func heading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.rvTextPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.rvTextSecondary)
        }
    }

    // MARK: - Actions

    private func next() {
        guard nameIssue == nil else { return }
        withAnimation(.spring(duration: 0.3)) { step = 3 }
    }

    private func finish() {
        guard nameIssue == nil, !favorites.isEmpty else { return }
        let player = Player.ensureMe(in: context)
        player.name = FriendForm.cleaned(name)
        player.colorHex = colorHex
        player.photo = photo
        // Keep the order of the grid, not the tap order.
        favoritesRaw = SportSettings.encode(SportType.phase1Sports.filter(favorites.contains))
        isOnboarded = true
    }
}

#Preview {
    OnboardingView()
        .modelContainer(SampleData.container(filled: false))
}
