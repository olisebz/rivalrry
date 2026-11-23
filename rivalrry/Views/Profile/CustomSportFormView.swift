import SwiftUI
import SwiftData

/// Create or edit a custom sport (plan.md §2.2 "Custom sport", §4 S9 "Sports").
/// Name, symbol instead of emoji (decision 4), scoring type, draws and team mode.
struct CustomSportFormView: View {
    /// `nil` = new sport.
    let sport: CustomSport?
    /// Called with the new sport after "Add", e.g. to select it in the grid.
    var onCreated: (CustomSport) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var customSports: [CustomSport]
    @Query private var matches: [Match]

    @State private var form: CustomSportForm
    @State private var showsIssue = false
    @State private var isConfirmingDelete = false
    @FocusState private var nameFocused: Bool

    init(sport: CustomSport? = nil, onCreated: @escaping (CustomSport) -> Void = { _ in }) {
        self.sport = sport
        self.onCreated = onCreated
        _form = State(initialValue: sport.map(CustomSportForm.init(sport:)) ?? CustomSportForm())
    }

    private var matchCount: Int {
        sport.map { CustomSports.matches(of: $0, in: matches).count } ?? 0
    }

    /// The scoring type is locked after the first match (the saved results depend on it).
    private var canChangeScoring: Bool { matchCount == 0 }

    private var issue: String? {
        form.issue(otherNames: customSports.filter { $0.id != sport?.id }.map(\.name))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    nameField
                    symbolPicker
                    scoringPicker
                    if form.showsSetRules { setRules }
                    if form.showsDraws || form.showsTeams { options }
                    if sport != nil { deleteButton }
                }
                .padding(Spacing.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.rvBackground)
            .safeAreaInset(edge: .bottom) {
                Button(sport == nil ? "Add" : "Save", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(issue != nil)
                    .padding(Spacing.m)
                    .background(Color.rvBackground)
            }
            .navigationTitle(sport == nil ? "New Sport" : "Edit Sport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog("Delete sport?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete Sport", role: .destructive, action: delete)
            } message: {
                Text(CustomSports.deleteWarning(matchCount: matchCount))
            }
            .onAppear { if sport == nil { nameFocused = true } }
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
                    showsIssue = true
                    if name.count > CustomSportForm.nameLimit { form.name = String(name.prefix(CustomSportForm.nameLimit)) }
                }
            if showsIssue, let issue, !form.trimmedName.isEmpty {
                Label(issue, systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color.rvTextSecondary)
            }
        }
    }

    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            label("Symbol")
            SymbolPicker(selection: $form.symbolName)
        }
    }

    private var scoringPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            label("Scoring")
            VStack(spacing: 0) {
                ForEach(CustomSport.scoringTypes, id: \.self) { type in
                    Button {
                        withAnimation(.spring(duration: 0.3)) { form.scoringType = type }
                    } label: {
                        HStack {
                            Text(type.customTitle)
                                .font(.body)
                                .foregroundStyle(canChangeScoring || form.scoringType == type
                                                 ? Color.rvTextPrimary : Color.rvTextTertiary)
                            Spacer()
                            if form.scoringType == type {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.rvAccent)
                            }
                        }
                        .padding(.vertical, Spacing.s + Spacing.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canChangeScoring)
                    .accessibilityAddTraits(form.scoringType == type ? .isSelected : [])
                    if type != CustomSport.scoringTypes.last {
                        Rectangle().fill(Color.rvSeparator).frame(height: 0.5)
                    }
                }
            }
            .padding(.horizontal, Spacing.m)
            .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            if !canChangeScoring {
                Text("The scoring can't be changed once the sport has matches.")
                    .font(.subheadline)
                    .foregroundStyle(Color.rvTextSecondary)
            }
        }
    }

    private var setRules: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            label("Set rules")
            VStack(spacing: 0) {
                Stepper("Points per set: \(form.pointsPerSet)", value: $form.pointsPerSet,
                        in: CustomSport.pointsPerSetRange)
                    .padding(.vertical, Spacing.s)
                Rectangle().fill(Color.rvSeparator).frame(height: 0.5)
                Stepper("Win by: \(form.winBy)", value: $form.winBy, in: CustomSport.winByRange)
                    .padding(.vertical, Spacing.s)
            }
            .font(.body.monospacedDigit())
            .foregroundStyle(Color.rvTextPrimary)
            .padding(.horizontal, Spacing.m)
            .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .disabled(!canChangeScoring)
        }
    }

    private var options: some View {
        VStack(spacing: 0) {
            if form.showsDraws {
                Toggle("Draws allowed", isOn: $form.allowsDraw)
                    .padding(.vertical, Spacing.s)
            }
            if form.showsDraws && form.showsTeams {
                Rectangle().fill(Color.rvSeparator).frame(height: 0.5)
            }
            if form.showsTeams {
                Toggle("Team mode allowed", isOn: $form.allowsTeams)
                    .padding(.vertical, Spacing.s)
            }
        }
        .font(.body)
        .foregroundStyle(Color.rvTextPrimary)
        // Neutral like the S9 toggles (design.md §1).
        .tint(Color.rvTextSecondary)
        .padding(.horizontal, Spacing.m)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var deleteButton: some View {
        Button("Delete Sport", role: .destructive) { isConfirmingDelete = true }
            .font(.headline)
            .foregroundStyle(Color.rvDestructive)
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color.rvTextSecondary)
    }

    // MARK: - Actions

    private func save() {
        guard issue == nil else { return }
        if let sport {
            form.apply(to: sport, canChangeScoring: canChangeScoring)
        } else {
            let new = form.makeSport()
            context.insert(new)
            onCreated(new)
        }
        dismiss()
    }

    private func delete() {
        guard let sport else { return }
        try? CustomSports.delete(sport, in: context)
        dismiss()
    }
}

#Preview("New Sport") {
    CustomSportFormView()
        .modelContainer(SampleData.container())
}
