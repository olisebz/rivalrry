import SwiftUI
import SwiftData

/// S4 – Add Friend (local, Phase 1–2), also used for "Edit Friend" from S2 and "Edit Profile" in S9.
/// Name, optional photo, color. No emoji: the avatar shows initials (decision 4).
struct FriendFormView: View {
    /// `nil` = add a new friend.
    let friend: Player?
    /// Set when pushed from S4 "Add Friend" ("Add Local Friend"): no own navigation stack,
    /// and "Add" calls this instead of dismissing.
    var onAdded: (() -> Void)? = nil

    @Query private var players: [Player]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.onlineBackend) private var backend

    @State private var name: String
    @State private var colorHex: String
    @State private var photo: Data?

    init(friend: Player? = nil, onAdded: (() -> Void)? = nil) {
        self.friend = friend
        self.onAdded = onAdded
        _name = State(initialValue: friend?.name ?? "")
        _colorHex = State(initialValue: friend?.colorHex ?? FriendForm.colors[0])
        _photo = State(initialValue: friend?.photo)
    }

    private var nameIssue: FriendForm.NameIssue? {
        FriendForm.validateName(name, existing: players, editing: friend)
    }

    private var title: String {
        guard let friend else { return "Add Friend" }
        return friend.isMe ? "Edit Profile" : "Edit Friend"
    }

    var body: some View {
        if onAdded != nil {
            form
        } else {
            NavigationStack {
                form
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                    }
            }
            .tint(Color.rvAccent)
        }
    }

    private var form: some View {
        ScrollView {
            PlayerFields(name: $name, colorHex: $colorHex, photo: $photo,
                         nameIssue: nameIssue, focusesName: friend == nil, onSubmit: save)
                .padding(Spacing.m)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.rvBackground)
        .safeAreaInset(edge: .bottom) {
            Button(friend == nil ? "Add" : "Save", action: save)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(nameIssue != nil)
                .padding(Spacing.m)
                .background(Color.rvBackground)
        }
        .navigationTitle(onAdded == nil ? title : "Add Local Friend")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() {
        guard nameIssue == nil else { return }
        let cleaned = FriendForm.cleaned(name)
        if let friend {
            friend.name = cleaned
            friend.colorHex = colorHex
            friend.photo = photo
            // Your online profile follows "Edit Profile" (Phase 3). Offline retries come in step 7.
            if friend.isMe {
                let backend = backend
                Task { try? await ProfileSync.push(friend, backend: backend) }
            }
        } else {
            context.insert(Player(name: cleaned, photo: photo, colorHex: colorHex))
        }
        if let onAdded { onAdded() } else { dismiss() }
    }
}

#Preview("Add Friend") {
    FriendFormView()
        .modelContainer(SampleData.container())
}

#Preview("Edit Friend") {
    let container = SampleData.container()
    return FriendFormView(friend: SampleData.player("Max Keller", in: container))
        .modelContainer(container)
}
