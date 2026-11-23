import SwiftUI
import SwiftData

/// S6 – Requests (plan.md §4 S6). Phase 3 step 2 has only "Friend requests";
/// the other sections follow in step 4.
struct RequestsView: View {
    @Query private var players: [Player]
    @Environment(\.modelContext) private var context
    @Environment(\.onlineFriends) private var online

    @State private var errorMessage: String?

    private var me: Player? { players.first(where: \.isMe) }

    var body: some View {
        NavigationStack {
            Group {
                if online.incoming.isEmpty {
                    ScrollView {
                        EmptyStateView(symbol: "tray", message: "All caught up.")
                            .containerRelativeFrame(.vertical)
                    }
                } else {
                    list
                }
            }
            .background(Color.rvBackground)
            .navigationTitle("Requests")
            .refreshable { await refresh() }
            .task { await refresh() }
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

    private var list: some View {
        List {
            Section {
                ForEach(online.incoming) { incoming in
                    OnlineProfileRow(profile: incoming.profile) {
                        HStack(spacing: Spacing.s) {
                            Button("Decline") { respond(incoming, accept: false) }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.rvTextSecondary)
                                .fixedSize()
                                .frame(minHeight: 44)
                            Button("Accept") { respond(incoming, accept: true) }
                                .buttonStyle(PillButtonStyle())
                        }
                        // Two buttons in one row: keep taps from hitting the whole row.
                        .buttonStyle(.borderless)
                    }
                    .listRowBackground(Color.rvBackground)
                }
            } header: {
                Text("Friend requests")
                    .font(.headline)
                    .foregroundStyle(Color.rvTextSecondary)
                    .textCase(nil)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func refresh() async {
        guard let me else { return }
        try? await online.syncAll(me: me, context: context)
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
            } catch {
                errorMessage = "Check your internet connection and try again."
            }
        }
    }
}

#Preview("Friend request") {
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
