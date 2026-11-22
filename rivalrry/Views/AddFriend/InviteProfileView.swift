import SwiftUI
import SwiftData

/// The user behind an invite link or a scanned QR code, with one button to add them.
/// Has no navigation stack of its own: shown in a sheet (invite link) or pushed (scanner).
struct InviteProfileView: View {
    let username: String

    @Query private var players: [Player]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.onlineFriends) private var online

    @State private var profile: OnlineProfile?
    @State private var isLoading = true
    @State private var isChoosingUsername = false
    @State private var errorMessage: String?

    private var me: Player? { players.first(where: \.isMe) }

    var body: some View {
        VStack(spacing: Spacing.l) {
            if isLoading {
                ProgressView()
            } else if let profile {
                AvatarView(name: profile.name, colorHex: profile.colorHex, photo: profile.photo, size: 96)
                VStack(spacing: Spacing.xs) {
                    Text(profile.name)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.rvTextPrimary)
                    Text("@\(profile.username)")
                        .font(.subheadline)
                        .foregroundStyle(Color.rvTextSecondary)
                }
                action(for: profile)
            } else {
                EmptyStateView(symbol: "person.crop.circle.badge.questionmark",
                               message: "No user found with the username @\(username).")
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.rvBackground)
        .navigationTitle("Add Friend")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isChoosingUsername) {
            if let me { UsernameFormView(me: me) }
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task { await load() }
    }

    @ViewBuilder
    private func action(for profile: OnlineProfile) -> some View {
        if let me, me.username != nil {
            switch online.relation(to: profile.userID) {
            case .none:
                Button("Send Friend Request") { add(profile, me: me) }
                    .buttonStyle(PrimaryButtonStyle())
            case .incoming:
                Button("Accept") { add(profile, me: me) }
                    .buttonStyle(PrimaryButtonStyle())
            case .requested:
                note("Request sent. \(profile.name) needs to accept it.")
            case .friends:
                note("You're already friends.")
            case .isMe:
                note("This is you.")
            }
        } else {
            note("Choose a username to add friends online.")
            Button("Choose Username") { isChoosingUsername = true }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(Color.rvTextSecondary)
            .multilineTextAlignment(.center)
    }

    private func load() async {
        defer { isLoading = false }
        if let me { try? await online.refresh(me: me, context: context) }
        profile = try? await online.backend.fetchProfile(username: username)
    }

    private func add(_ profile: OnlineProfile, me: Player) {
        Task {
            do {
                try await online.add(profile, me: me, context: context)
            } catch {
                errorMessage = "Check your internet connection and try again."
            }
        }
    }
}

/// Sheet for an opened invite link: the profile plus "Done".
struct InviteSheet: View {
    let username: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            InviteProfileView(username: username)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .tint(Color.rvAccent)
    }
}

#Preview {
    let container = SampleData.container()
    let me = (try? container.mainContext.fetch(FetchDescriptor<Player>()))?.first(where: \.isMe)
    me?.username = "alex"
    me?.cloudUserID = "local-user"
    return InviteSheet(username: "tom_berger")
        .modelContainer(container)
        .environment(\.onlineFriends, OnlineFriends(backend: InMemoryBackend.withTestUsers()))
}
