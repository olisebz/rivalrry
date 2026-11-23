import SwiftUI
import SwiftData

/// "New Group" from S1 and "Edit Group" in S8 (plan.md §4 S8): name, symbol instead of emoji
/// (decision 4), members. Editing renames the group and adds or removes members.
struct GroupFormView: View {
    /// `nil` = new group.
    let group: PlayerGroup?

    @Query private var players: [Player]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.onlineBackend) private var backend

    @State private var form: GroupForm
    @State private var isSaving = false
    @FocusState private var nameFocused: Bool

    init(group: PlayerGroup? = nil) {
        self.group = group
        _form = State(initialValue: group.map(GroupForm.init(group:)) ?? GroupForm())
    }

    private var me: Player? { players.first(where: \.isMe) }
    private var candidates: [Player] { GroupForm.candidates(in: players, group: group) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    nameField
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        label("Symbol")
                        SymbolPicker(selection: $form.symbolName)
                    }
                    memberPicker
                }
                .padding(Spacing.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.rvBackground)
            .safeAreaInset(edge: .bottom) {
                Button(group == nil ? "Add" : "Save", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(form.issue != nil || isSaving)
                    .padding(Spacing.m)
                    .background(Color.rvBackground)
            }
            .navigationTitle(group == nil ? "New Group" : "Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { if group == nil { nameFocused = true } }
        }
        .tint(Color.rvAccent)
    }

    // MARK: - Fields

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            label("Name")
            TextField("Name", text: $form.name)
                .font(.body)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($nameFocused)
                .padding(Spacing.m)
                .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                .onChange(of: form.name) { _, name in
                    if name.count > GroupForm.nameLimit { form.name = String(name.prefix(GroupForm.nameLimit)) }
                }
        }
    }

    private var memberPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            label("Members")
            VStack(spacing: 0) {
                ForEach(candidates) { friend in
                    memberRow(friend)
                    if friend.id != candidates.last?.id {
                        Rectangle().fill(Color.rvSeparator).frame(height: 0.5)
                    }
                }
            }
            .padding(.horizontal, Spacing.m)
            .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            Text("Only friends with the app see the group.")
                .font(.subheadline)
                .foregroundStyle(Color.rvTextSecondary)
        }
    }

    private func memberRow(_ friend: Player) -> some View {
        let isSelected = form.memberIDs.contains(friend.id)
        return Button {
            if isSelected { form.memberIDs.remove(friend.id) } else { form.memberIDs.insert(friend.id) }
        } label: {
            HStack(spacing: Spacing.m) {
                AvatarView(player: friend, size: 32)
                Text(friend.name)
                    .font(.body)
                    .foregroundStyle(Color.rvTextPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.rvAccent : Color.rvTextTertiary)
            }
            .padding(.vertical, Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color.rvTextSecondary)
    }

    // MARK: - Actions

    private func save() {
        guard form.issue == nil, let me else { return }
        isSaving = true
        Task {
            // Offline it's queued in the Outbox; the changes show here right away.
            if let group {
                if group.name != form.trimmedName || group.symbolName != form.symbolName {
                    try? await GroupSync.rename(group, name: form.trimmedName, symbolName: form.symbolName,
                                                me: me, context: context, backend: backend)
                }
                let changes = form.memberChanges(for: group, players: players)
                if !changes.added.isEmpty {
                    try? await GroupSync.add(changes.added, to: group, context: context, backend: backend)
                }
                for player in changes.removed {
                    try? await GroupSync.remove(player, from: group, context: context, backend: backend)
                }
            } else {
                try? await GroupSync.create(name: form.trimmedName, symbolName: form.symbolName,
                                            friends: form.members(from: players), me: me,
                                            context: context, backend: backend)
            }
            dismiss()
        }
    }
}

#Preview("New Group") {
    GroupFormView()
        .modelContainer(SampleData.container())
}
