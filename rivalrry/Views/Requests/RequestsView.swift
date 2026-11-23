import SwiftUI
import SwiftData

/// S6 – Requests (plan.md §4 S6): "To confirm", "Imported matches", "Deletion requests",
/// "Friend requests", "Waiting for others".
struct RequestsView: View {
    @Query private var players: [Player]
    @Query private var matches: [Match]
    @Environment(\.modelContext) private var context
    @Environment(\.onlineFriends) private var online
    @Environment(\.connectivity) private var connectivity
    @Query private var pendingActions: [PendingAction]

    @State private var rejecting: Match?
    @State private var errorMessage: String?

    private var me: Player? { players.first(where: \.isMe) }

    var body: some View {
        NavigationStack {
            Group {
                if let me, !isEmpty(MatchRequests(matches: matches, me: me)) {
                    list(MatchRequests(matches: matches, me: me), me: me)
                } else {
                    ScrollView {
                        EmptyStateView(symbol: "tray", message: "All caught up.")
                            .containerRelativeFrame(.vertical)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !connectivity.isOnline { offlineNote }
            }
            .background(Color.rvBackground)
            .navigationTitle("Requests")
            .navigationDestination(for: Match.self) { match in
                if let me { MatchDetailView(match: match, me: me) }
            }
            .navigationDestination(for: ImportReview.self) { review in
                if let me { ImportReviewView(creatorID: review.creatorID, me: me) }
            }
            .refreshable { await refresh() }
            .task { await refresh() }
            .sheet(item: $rejecting) { match in
                if let me { RejectMatchView(match: match, me: me) }
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
    }

    /// Offline note (Phase 3 decision: only here, with the number of waiting changes).
    private var offlineNote: some View {
        let waiting = pendingActions.count + matches.filter(\.isWaitingForUpload).count
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Label("You're offline. Changes are sent when you're back online.", systemImage: "wifi.slash")
                .font(.subheadline)
                .foregroundStyle(Color.rvTextPrimary)
            if waiting > 0 {
                Text(waiting == 1 ? "1 change waiting" : "\(waiting) changes waiting")
                    .font(.subheadline)
                    .foregroundStyle(Color.rvTextSecondary)
                    .padding(.leading, 28)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(Color.rvSurface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .padding(.horizontal, Spacing.m)
        .padding(.bottom, Spacing.s)
        .background(Color.rvBackground)
    }

    private func isEmpty(_ requests: MatchRequests) -> Bool {
        requests.toConfirm.isEmpty && requests.imported.isEmpty && requests.deletionRequests.isEmpty
            && requests.waitingForOthers.isEmpty && online.incoming.isEmpty
    }

    private func list(_ requests: MatchRequests, me: Player) -> some View {
        List {
            if !requests.toConfirm.isEmpty {
                Section {
                    ForEach(requests.toConfirm) { match in
                        RequestMatchRow(match: match, me: me, subtitle: confirmSubtitle(match),
                                        score: match.changeScoreText(for: me) ?? match.scoreText(for: me)) {
                            secondaryButton("Reject") { rejecting = match }
                            Button("Confirm") {
                                run { try await MatchSync.confirm(match, me: me, backend: $0) }
                            }
                            .buttonStyle(PillButtonStyle())
                        }
                    }
                } header: { header("To confirm") }
            }
            if !requests.imported.isEmpty {
                // One bulk request per friend (plan.md §6.3 point 4).
                Section {
                    ForEach(requests.imported) { group in
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            HStack(spacing: Spacing.m) {
                                AvatarView(player: group.creator, size: 44)
                                Text(group.title)
                                    .font(.body)
                                    .foregroundStyle(Color.rvTextPrimary)
                            }
                            HStack(spacing: Spacing.s) {
                                Spacer()
                                NavigationLink(value: ImportReview(creatorID: group.creator.id)) {
                                    Text("Review")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.rvTextSecondary)
                                        .fixedSize()
                                        .frame(minHeight: 44)
                                }
                                Button("Confirm All") {
                                    run { backend in
                                        for match in group.matches {
                                            try await MatchSync.confirm(match, me: me, backend: backend)
                                        }
                                    }
                                }
                                .buttonStyle(PillButtonStyle())
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, Spacing.xs)
                        .listRowBackground(Color.rvBackground)
                    }
                } header: { header("Imported matches") }
            }
            if !requests.deletionRequests.isEmpty {
                Section {
                    ForEach(requests.deletionRequests) { match in
                        RequestMatchRow(match: match, me: me, subtitle: match.deletionText(me: me) ?? "",
                                        score: match.scoreText(for: me)) {
                            secondaryButton("Decline") {
                                run { try await MatchSync.answerDeletion(match, approve: false, me: me, backend: $0) }
                            }
                            Button("Approve") {
                                run { try await MatchSync.answerDeletion(match, approve: true, me: me, backend: $0) }
                            }
                            .buttonStyle(PillButtonStyle())
                        }
                    }
                } header: { header("Deletion requests") }
            }
            if !online.incoming.isEmpty {
                Section {
                    ForEach(online.incoming) { incoming in
                        OnlineProfileRow(profile: incoming.profile) {
                            HStack(spacing: Spacing.s) {
                                secondaryButton("Decline") { respond(incoming, accept: false) }
                                Button("Accept") { respond(incoming, accept: true) }
                                    .buttonStyle(PillButtonStyle())
                            }
                            // Two buttons in one row: keep taps from hitting the whole row.
                            .buttonStyle(.borderless)
                        }
                        .listRowBackground(Color.rvBackground)
                    }
                } header: { header("Friend requests") }
            }
            if !requests.waitingForOthers.isEmpty {
                Section {
                    ForEach(requests.waitingForOthers) { match in
                        RequestMatchRow(match: match, me: me,
                                        subtitle: (match.status == .pending ? match.statusText : match.changeText) ?? "",
                                        score: match.changeScoreText(for: me) ?? match.scoreText(for: me)) {
                            if match.canRemind(by: me) {
                                Button("Remind") {
                                    MatchSync.remind(match, me: me)
                                    run { _ in }
                                }
                                .buttonStyle(PillButtonStyle())
                            } else if let remindedAt = match.remindedAt {
                                Text(RemindText.text(for: remindedAt))
                                    .font(.subheadline)
                                    .foregroundStyle(Color.rvTextSecondary)
                            }
                        }
                    }
                } header: { header("Waiting for others") }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// "Max · Yesterday", or "Change by Max · Yesterday" for a change to a confirmed match.
    private func confirmSubtitle(_ match: Match) -> String {
        let creator = match.createdBy?.shortName ?? "Deleted Player"
        let date = MatchDate.text(for: match.date)
        return match.status == .confirmed ? "Change by \(creator) · \(date)" : "\(creator) · \(date)"
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Color.rvTextSecondary)
            .textCase(nil)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.rvTextSecondary)
            .fixedSize()
            .frame(minHeight: 44)
    }

    private func refresh() async {
        guard let me else { return }
        try? await online.syncAll(me: me, context: context)
    }

    /// Runs an online action, then syncs; shows an alert if it fails.
    private func run(_ action: @escaping (any OnlineBackend) async throws -> Void) {
        guard let me else { return }
        let backend = online.backend
        Task {
            do {
                try await action(backend)
                try await online.syncMatches(me: me, context: context)
            } catch {
                errorMessage = "Check your internet connection and try again."
            }
        }
    }

    private func respond(_ incoming: OnlineFriends.Incoming, accept: Bool) {
        guard let me else { return }
        Task {
            do {
                if accept {
                    try await online.accept(incoming, me: me, context: context)
                } else {
                    try await online.decline(incoming, me: me, context: context)
                }
                try await online.syncMatches(me: me, context: context)
            } catch {
                errorMessage = "Check your internet connection and try again."
            }
        }
    }
}

/// Navigation value for "Review" of one friend's imported matches.
private struct ImportReview: Hashable {
    let creatorID: UUID
}

/// "Review": the imported matches of one friend, one by one (plan.md §6.3 point 4).
private struct ImportReviewView: View {
    let creatorID: UUID
    let me: Player

    @Query private var matches: [Match]
    @Environment(\.modelContext) private var context
    @Environment(\.onlineFriends) private var online
    @Environment(\.dismiss) private var dismiss
    @State private var rejecting: Match?
    @State private var errorMessage: String?

    private var group: MatchRequests.ImportGroup? {
        MatchRequests(matches: matches, me: me).imported.first { $0.creator.id == creatorID }
    }

    var body: some View {
        List {
            ForEach(group?.matches ?? []) { match in
                RequestMatchRow(match: match, me: me, subtitle: MatchDate.text(for: match.date),
                                score: match.scoreText(for: me)) {
                    Button("Reject") { rejecting = match }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.rvTextSecondary)
                        .fixedSize()
                        .frame(minHeight: 44)
                    Button("Confirm") { confirm(match) }
                        .buttonStyle(PillButtonStyle())
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.rvBackground)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Match.self) { MatchDetailView(match: $0, me: me) }
        .sheet(item: $rejecting) { RejectMatchView(match: $0, me: me) }
        // All answered: back to Requests.
        .onChange(of: group == nil) { _, isDone in if isDone { dismiss() } }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func confirm(_ match: Match) {
        Task {
            do {
                try await MatchSync.confirm(match, me: me, backend: online.backend)
                try await online.syncMatches(me: me, context: context)
            } catch {
                errorMessage = "Check your internet connection and try again."
            }
        }
    }
}

/// One match in S6: sport, a short line, the result preview and the buttons. Tap opens S3.
private struct RequestMatchRow<Buttons: View>: View {
    let match: Match
    let me: Player
    let subtitle: String
    let score: String
    @ViewBuilder var buttons: () -> Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
                Image(systemName: match.sport.symbolName)
                    .foregroundStyle(Color.rvTextPrimary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(match.sport.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.rvTextPrimary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.rvTextSecondary)
                }
                Spacer(minLength: Spacing.s)
                Text(score)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.rvTextPrimary)
            }
            HStack(spacing: Spacing.s) {
                Spacer()
                buttons()
            }
            // Buttons in a row: keep taps from opening the match.
            .buttonStyle(.borderless)
        }
        .padding(.vertical, Spacing.xs)
        // Invisible link: tapping outside the buttons opens S3 without a chevron.
        .background(NavigationLink(value: match) { EmptyView() }.opacity(0))
        .listRowBackground(Color.rvBackground)
    }
}

/// "Reject" with a required reason (plan.md §4 S6).
private struct RejectMatchView: View {
    let match: Match
    let me: Player

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.onlineFriends) private var online
    @State private var reason = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private var trimmed: String { reason.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Reason")
                        .font(.subheadline)
                        .foregroundStyle(Color.rvTextSecondary)
                    TextField("It was 21–19, not 21–17", text: $reason, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($isFocused)
                        .padding(Spacing.m)
                        .background(Color.rvSurface,
                                    in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                    Text("\(match.createdBy?.shortName ?? "The creator") can then edit and resend the match, or delete it.")
                        .font(.subheadline)
                        .foregroundStyle(Color.rvTextSecondary)
                }
                .padding(Spacing.m)
            }
            .background(Color.rvBackground)
            .safeAreaInset(edge: .bottom) {
                Button("Reject", action: reject)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(trimmed.isEmpty || isSaving)
                    .padding(Spacing.m)
                    .background(Color.rvBackground)
            }
            .navigationTitle("Reject Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Something Went Wrong", isPresented: Binding(
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

    private func reject() {
        guard !trimmed.isEmpty, !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await MatchSync.reject(match, reason: trimmed, me: me, backend: online.backend)
                try await online.syncMatches(me: me, context: context)
                dismiss()
            } catch {
                errorMessage = "Check your internet connection and try again."
            }
        }
    }
}

#Preview("Requests") {
    let container = SampleData.container()
    let me = (try? container.mainContext.fetch(FetchDescriptor<Player>()))?.first(where: \.isMe)
    me?.username = "alex"
    me?.cloudUserID = "local-user"
    return RequestsView()
        .modelContainer(container)
        .environment(\.onlineFriends, OnlineFriends(backend: InMemoryBackend.withTestUsers()))
}

#Preview("All caught up") {
    RequestsView()
        .modelContainer(SampleData.container())
}
