import SwiftUI
import SwiftData

/// Choose or change your online username (plan.md §6.1, S9 "from Phase 3 username").
struct UsernameFormView: View {
    let me: Player

    @Environment(\.onlineBackend) private var backend
    @Environment(\.onlineFriends) private var online
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var username: String
    /// Set after "Save" when the backend says the name is taken.
    @State private var isTaken = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    init(me: Player) {
        self.me = me
        _username = State(initialValue: me.username ?? "")
    }

    private var issue: Username.Issue? {
        isTaken ? .taken : Username.validate(username)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Username")
                        .font(.subheadline)
                        .foregroundStyle(Color.rvTextSecondary)
                    HStack(spacing: Spacing.xs) {
                        Text("@")
                            .foregroundStyle(Color.rvTextSecondary)
                        TextField("username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .submitLabel(.done)
                            .focused($isFocused)
                            .onSubmit(save)
                    }
                    .font(.body)
                    .padding(Spacing.m)
                    .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                    .onChange(of: username) { _, newValue in
                        isTaken = false
                        // Hard limit while typing, like the name field.
                        if newValue.count > Username.maxLength { username = String(newValue.prefix(Username.maxLength)) }
                    }
                    if !username.isEmpty, let issue {
                        Label(issue.message, systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(Color.rvTextSecondary)
                    } else {
                        Text("Friends find you by your username.")
                            .font(.subheadline)
                            .foregroundStyle(Color.rvTextSecondary)
                    }
                }
                .padding(Spacing.m)
            }
            .background(Color.rvBackground)
            .safeAreaInset(edge: .bottom) {
                Button("Save", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(issue != nil || isSaving)
                    .padding(Spacing.m)
                    .background(Color.rvBackground)
            }
            .navigationTitle(me.username == nil ? "Choose Username" : "Change Username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Couldn't Save", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear { isFocused = true }
        }
        .tint(Color.rvAccent)
    }

    private func save() {
        guard issue == nil, !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let result = try await ProfileSync.claimUsername(username, for: me, backend: backend)
                if result == .taken {
                    isTaken = true
                } else if result == nil {
                    // Now online: load friend requests that were waiting for you.
                    try? await online.refresh(me: me, context: context)
                    dismiss()
                }
            } catch OnlineError.noAccount {
                errorMessage = "Sign in to iCloud in Settings to go online."
            } catch {
                errorMessage = "Check your internet connection and try again."
            }
        }
    }
}

#Preview {
    let container = SampleData.container()
    let me = (try? container.mainContext.fetch(FetchDescriptor<Player>()))?.first(where: \.isMe)
    return UsernameFormView(me: me ?? Player(name: "You", isMe: true))
        .modelContainer(container)
        .environment(\.onlineBackend, InMemoryBackend(profiles: [
            OnlineProfile(userID: "max", username: "max", name: "Max Keller", colorHex: "4F6BED"),
        ]))
}
