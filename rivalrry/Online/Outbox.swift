import Foundation
import SwiftData

/// An online action that couldn't be sent yet (plan.md §6.1 "Offline"). New and edited matches don't need
/// one: they wait with `Match.needsUpload`.
enum OutboxAction: Codable, Equatable {
    /// Confirm, Reject, Request deletion, Approve, Decline.
    case response(MatchResponse)
    /// Deleting your own online match.
    case deleteMatch(UUID)
    /// Your profile after "Edit Profile".
    case profile(OnlineProfile)
    /// Your link after "Link to Account".
    case link(LinkRecord)
}

/// One queued action, kept until it's sent (survives closing the app).
@Model
final class PendingAction {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    /// `OutboxAction`, JSON.
    var payload: Data = Data()

    init(_ action: OutboxAction, createdAt: Date = Date()) {
        self.createdAt = createdAt
        self.payload = (try? JSONEncoder().encode(action)) ?? Data()
    }

    var action: OutboxAction? { try? JSONDecoder().decode(OutboxAction.self, from: payload) }
}

/// Sends online actions right away, or queues them while offline and sends them in order later.
enum Outbox {

    /// Sends `action`, or queues it if there's no connection (or older actions are still waiting,
    /// so the order stays the same). Other errors are passed on.
    static func send(_ action: OutboxAction, backend: any OnlineBackend, context: ModelContext) async throws {
        if try waiting(in: context).isEmpty {
            do {
                try await perform(action, backend: backend)
                return
            } catch OnlineError.offline {
                // Falls through to the queue.
            }
        }
        enqueue(action, context: context)
    }

    /// Sends everything that's waiting, oldest first. Stops at the first `.offline`; an action the server
    /// refuses (e.g. the match was deleted meanwhile) is dropped so it doesn't block the rest.
    static func flush(backend: any OnlineBackend, context: ModelContext) async throws {
        for pending in try waiting(in: context) {
            guard let action = pending.action else {
                context.delete(pending)
                continue
            }
            do {
                try await perform(action, backend: backend)
            } catch OnlineError.offline {
                throw OnlineError.offline
            } catch {
                // Not sendable anymore: drop it.
            }
            context.delete(pending)
        }
    }

    static func waiting(in context: ModelContext) throws -> [PendingAction] {
        try context.fetch(FetchDescriptor<PendingAction>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private static func enqueue(_ action: OutboxAction, context: ModelContext) {
        // Only the newest profile matters.
        if case .profile = action, let waiting = try? waiting(in: context) {
            for pending in waiting {
                if case .profile = pending.action { context.delete(pending) }
            }
        }
        context.insert(PendingAction(action))
    }

    private static func perform(_ action: OutboxAction, backend: any OnlineBackend) async throws {
        switch action {
        case .response(let response): try await backend.saveResponse(response)
        case .deleteMatch(let id): try await backend.deleteMatch(id: id)
        case .profile(let profile): try await backend.saveProfile(profile)
        case .link(let link): try await backend.saveLink(link)
        }
    }
}

extension Match {
    /// Waits to be uploaded (new, edited, Remind).
    var isWaitingForUpload: Bool { needsUpload && createdBy?.isMe == true }
}
