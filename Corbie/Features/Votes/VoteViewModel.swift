import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class VoteViewModel {
    private(set) var vote: VoteDTO
    private(set) var selection: Set<Int> = []
    private(set) var isSaving = false

    @ObservationIgnored private var environment: AppEnvironment?

    init(vote: VoteDTO) {
        self.vote = vote
    }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
        syncSelection()
    }

    var outcome: VoteOutcome {
        VoteOutcome.make(
            vote: vote,
            viewerMemberId: environment?.currentMember?.id,
            partnerMemberId: environment?.partner?.id
        )
    }

    var hasAnswered: Bool {
        guard let memberId = environment?.currentMember?.id else { return false }
        return vote.responses.hasAnswered(memberId)
    }

    var canSubmit: Bool {
        isSaving == false && selection.isEmpty == false
    }

    var partnerVisibleOptions: Set<Int> {
        Set(outcome.partnerVisibleOptions())
    }

    func toggle(_ index: Int) {
        guard vote.options.indices.contains(index) else { return }
        if vote.mode == .single {
            selection = [index]
        } else if selection.contains(index) {
            selection.remove(index)
        } else {
            selection.insert(index)
        }
    }

    func submit() async -> VoteDTO? {
        guard let environment, let memberId = environment.currentMember?.id, canSubmit else { return nil }
        isSaving = true
        defer { isSaving = false }
        let wasRevealed = vote.isRevealed
        do {
            var updated = try await environment.repositories.votes.respond(
                voteId: vote.id,
                memberId: memberId,
                optionIndexes: selection.sorted()
            )
            environment.analytics.record(.voteAnswered)
            let memberCount = environment.space?.memberCount ?? 0
            if updated.isRevealed == false, updated.canReveal(memberCount: memberCount) {
                updated = try await environment.repositories.votes.reveal(voteId: updated.id)
            }
            if wasRevealed == false, updated.isRevealed {
                environment.analytics.record(.voteRevealed)
            }
            vote = updated
            return updated
        } catch {
            environment.report(error)
            return nil
        }
    }

    func refresh() async {
        guard let environment else { return }
        do {
            guard let stored = try await environment.repositories.votes.vote(id: vote.id) else { return }
            vote = stored
            syncSelection()
        } catch {
            environment.report(error)
        }
    }

    private func syncSelection() {
        guard let memberId = environment?.currentMember?.id, let mine = vote.responses[memberId] else { return }
        selection = Set(mine)
    }
}
