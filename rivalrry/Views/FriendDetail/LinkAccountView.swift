import SwiftUI
import SwiftData

/// "Link to Account" (plan.md §6.3): pick the online friend who is this local friend. Your old matches
/// with them are then imported (or not, see `AccountLinking`).
struct LinkAccountView: View {
    let friend: Player

    @Query private var players: [Player]
    @Query private var matches: [Match]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.onlineFriends) private var online

    @State private var selected: Player?
    @State private var isLinking = false
    @State private var result: ResultMessage?
    @State private var choosingImporter: Player?
    @State private var friendCount = 0
    @State private var errorMessage: String?

    private struct ResultMessage: Identifiable {
        let title: String
        let message: String
        var id: String { title }
    }

    private var me: Player? { players.first(where: \.isMe) }

    private var candidates: [Player] {
        AccountLinking.candidates(in: players).filter { $0.id != friend.id }
    }

    private var oldMatchCount: Int {
        me.map { AccountLinking.localMatches(with: friend, me: $0, in: matches).count } ?? 0
    }

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    EmptyStateView(symbol: "person.crop.circle.badge.plus",
                                   message: "Add \(friend.shortName) as an online friend first.")
                } else {
                    list
                }
            }
            .background(Color.rvBackground)
            .navigationTitle("Link to Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(selected.map { "Link \(friend.shortName) to @\($0.username ?? "")?" } ?? "",
                                isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }),
                                titleVisibility: .visible, presenting: selected) { candidate in
                Button("Link to Account") { link(to: candidate) }
            } message: { candidate in
                Text(oldMatchCount == 0
                     ? "\(friend.shortName) and \(candidate.shortName) become one friend."
                     : "\(friend.shortName) and \(candidate.shortName) become one friend. Your \(matchesText(oldMatchCount)) "
                        + "with \(friend.shortName) are sent to \(candidate.shortName) for confirmation.")
            }
            // Both have old matches and nobody imported yet (plan.md §6.3 point 7).
            .confirmationDialog(choosingImporter.map { "\($0.shortName) also has local matches with you. Who imports?" } ?? "",
                                isPresented: Binding(get: { choosingImporter != nil },
                                                     set: { if !$0 { choosingImporter = nil } }),
                                titleVisibility: .visible, presenting: choosingImporter) { linked in
                Button("I import") { choose(youImport: true, friend: linked) }
                Button("\(linked.shortName) imports") { choose(youImport: false, friend: linked) }
            } message: { linked in
                Text("You have \(matchesText(oldMatchCount)), \(linked.shortName) has \(matchesText(friendCount)). "
                     + "The other copies stay on the phone as \"Local only\" and don't count.")
            }
            .alert(item: $result) { result in
                Alert(title: Text(result.title), message: Text(result.message),
                      dismissButton: .default(Text("OK")) { dismiss() })
            }
            .alert("Something Went Wrong", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .tint(Color.rvAccent)
    }

    private var list: some View {
        List {
            Section {
                ForEach(candidates) { candidate in
                    Button {
                        selected = candidate
                    } label: {
                        OnlineProfileRow(profile: OnlineProfile(
                            userID: candidate.cloudUserID ?? "", username: candidate.username ?? "",
                            name: candidate.name, colorHex: candidate.colorHex, photo: candidate.photo)) {
                            EmptyView()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isLinking)
                    .listRowBackground(Color.rvBackground)
                }
            } header: {
                Text("Who is \(friend.shortName)?")
                    .font(.headline)
                    .foregroundStyle(Color.rvTextSecondary)
                    .textCase(nil)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func matchesText(_ count: Int) -> String {
        count == 1 ? "1 match" : "\(count) matches"
    }

    private func link(to candidate: Player) {
        guard let me else { return }
        let count = oldMatchCount
        isLinking = true
        Task {
            defer { isLinking = false }
            do {
                let outcome = try await AccountLinking.link(friend, to: candidate, me: me, context: context,
                                                            backend: online.backend)
                try await online.syncMatches(me: me, context: context)
                switch outcome {
                case .importing(let imported):
                    result = ResultMessage(title: "Linked",
                                           message: "\(matchesText(imported)) sent to \(friend.shortName) for confirmation.")
                case .alreadyImported(let name, let theirs):
                    // plan.md §6.3: "Alex already imported 12 matches with you."
                    result = ResultMessage(title: "\(name) already imported \(matchesText(theirs)) with you.",
                                           message: count == 0 ? "" : "Your own \(matchesText(count)) with \(name) "
                                               + "stay on this iPhone as \"Local only\" and don't count.")
                case .chooseImporter(let theirs):
                    friendCount = theirs
                    choosingImporter = friend
                case .nothingToImport:
                    dismiss()
                }
            } catch {
                errorMessage = "Check your internet connection and try again."
            }
        }
    }

    private func choose(youImport: Bool, friend linked: Player) {
        guard let me else { return }
        Task {
            do {
                try await AccountLinking.chooseImporter(youImport: youImport, friend: linked, me: me,
                                                        context: context, backend: online.backend)
                try await online.syncMatches(me: me, context: context)
                dismiss()
            } catch {
                errorMessage = "Check your internet connection and try again."
            }
        }
    }
}
