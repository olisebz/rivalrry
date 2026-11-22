import SwiftUI
import SwiftData

/// S4 – Add Friend, online (plan.md §4 S4 "From Phase 3"): search by username, your QR code,
/// "Share Invite Link", "Scan QR Code". "Add Local Friend" opens the local form for friends without the app.
struct AddFriendView: View {
    @Query private var players: [Player]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.onlineFriends) private var online

    @State private var query = ""
    @State private var results: [OnlineProfile] = []
    @State private var isAddingLocal = false
    @State private var isScanning = false
    @State private var isChoosingUsername = false
    @State private var errorMessage: String?

    private var me: Player? { players.first(where: \.isMe) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    if let me, let username = me.username {
                        searchSection(me)
                        inviteSection(username)
                    } else {
                        usernameHint
                    }
                    addLocalRow
                }
                .padding(Spacing.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.rvBackground)
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $isAddingLocal) {
                FriendFormView(onAdded: { dismiss() })
            }
            .sheet(isPresented: $isScanning) { ScanQRCodeView() }
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
            // Search as you type, with a short pause so not every key press hits the server.
            .task(id: query) { await search() }
            .task {
                if let me { try? await online.refresh(me: me, context: context) }
            }
        }
        .tint(Color.rvAccent)
    }

    // MARK: - Search

    private func searchSection(_ me: Player) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.rvTextSecondary)
                TextField("Search by username", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
            }
            .font(.body)
            .padding(Spacing.m)
            .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))

            ForEach(results, id: \.userID) { profile in
                OnlineProfileRow(profile: profile) {
                    RelationControl(relation: online.relation(to: profile.userID)) {
                        add(profile, me: me)
                    }
                }
            }
            if results.isEmpty, Username.cleaned(query).count >= Username.minLength {
                Text("No user found.")
                    .font(.subheadline)
                    .foregroundStyle(Color.rvTextSecondary)
                    .padding(.vertical, Spacing.s)
            }
        }
    }

    private func search() async {
        let prefix = Username.cleaned(query)
        guard !prefix.isEmpty else {
            results = []
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        results = (try? await online.backend.searchProfiles(prefix: prefix)) ?? []
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

    // MARK: - Invite

    private func inviteSection(_ username: String) -> some View {
        VStack(spacing: Spacing.m) {
            if let qrCode = Invite.qrCode(for: username) {
                Image(uiImage: qrCode)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .padding(Spacing.m)
                    // Always white behind the code, also in dark mode, so cameras can read it.
                    .background(.white, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .accessibilityLabel("Your QR code")
            }
            Text("@\(username)")
                .font(.headline)
                .foregroundStyle(Color.rvTextPrimary)
            ShareLink(item: Invite.url(for: username),
                      message: Text("Add me on RIVALRRY: @\(username)")) {
                Label("Share Invite Link", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(SecondaryButtonStyle())
            Button {
                isScanning = true
            } label: {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }

    /// Online friends need your own username first (plan.md §6.1).
    private var usernameHint: some View {
        VStack(spacing: Spacing.m) {
            Text("Choose a username to add friends online.")
                .font(.body)
                .foregroundStyle(Color.rvTextSecondary)
                .multilineTextAlignment(.center)
            Button("Choose Username") { isChoosingUsername = true }
                .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Local

    private var addLocalRow: some View {
        Button {
            isAddingLocal = true
        } label: {
            HStack(spacing: Spacing.m) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Local Friend")
                        .font(.body)
                        .foregroundStyle(Color.rvTextPrimary)
                    Text("For friends without the app.")
                        .font(.subheadline)
                        .foregroundStyle(Color.rvTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.rvTextTertiary)
            }
            .foregroundStyle(Color.rvTextPrimary)
            .padding(Spacing.m)
            .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("With username") {
    let container = SampleData.container()
    let me = (try? container.mainContext.fetch(FetchDescriptor<Player>()))?.first(where: \.isMe)
    me?.username = "alex"
    me?.cloudUserID = "local-user"
    return AddFriendView()
        .modelContainer(container)
        .environment(\.onlineFriends, OnlineFriends(backend: InMemoryBackend.withTestUsers()))
}

#Preview("No username") {
    AddFriendView()
        .modelContainer(SampleData.container())
}
