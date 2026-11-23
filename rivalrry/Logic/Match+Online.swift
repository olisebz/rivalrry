import Foundation

extension Match {
    /// Who has to confirm: the other team (1v1, Team) or everyone else (Race). Same rule as
    /// `MatchRecord.opponentUserIDs`.
    var confirmingParticipants: [MatchParticipant] {
        let creatorSide = participants.first { $0.player?.id == createdBy?.id }?.side
        return participants.filter {
            $0.player?.id != createdBy?.id && (mode == .race || $0.side != creatorSide)
        }
    }

    /// Opponents who haven't confirmed the current version yet.
    var waitingParticipants: [MatchParticipant] {
        confirmingParticipants.filter { !confirmedUserIDs.contains($0.player?.cloudUserID ?? "") }
    }

    /// S3 status banner (plan.md §4 S3): "Waiting for Max to confirm", "Confirmed",
    /// "Rejected by Max: It was 21–19". `nil` for local matches.
    var statusText: String? {
        switch status {
        case .local:
            return nil
        case .confirmed:
            return "Confirmed"
        case .pending:
            let names = waitingParticipants.map { $0.player.map { $0.isMe ? "you" : $0.shortName } ?? "Deleted Player" }
            guard !names.isEmpty else { return "Waiting for confirmation" }
            return "Waiting for \(names.formatted(.list(type: .and).locale(Locale(identifier: "en_US")))) to confirm"
        case .rejected:
            let rejecter = participants.first { $0.player?.cloudUserID == rejectedByUserID }?.player
            let name = rejecter.map { $0.isMe ? "you" : $0.shortName } ?? "an opponent"
            guard let reason = rejectionReason, !reason.isEmpty else { return "Rejected by \(name)" }
            return "Rejected by \(name): \(reason)"
        }
    }

    /// S3 rights from Phase 3 (plan.md §4 S3). Local matches: any time. Online matches: only the creator,
    /// while `Pending` or `Rejected`. Confirmed matches and other people's matches follow in step 4.
    var canEditOrDelete: Bool {
        switch status {
        case .local: true
        case .pending, .rejected: createdBy?.isMe == true
        case .confirmed: false
        }
    }
}
