import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class VotesViewModel {
    private(set) var votes: [VoteDTO] = []
    private(set) var isLoading = true
    var isEditorPresented = false

    @ObservationIgnored private var environment: AppEnvironment?

    func load(_ environment: AppEnvironment) async {
        self.environment = environment
        defer { isLoading = false }
        guard let space = environment.space else {
            votes = []
            return
        }
        do {
            votes = try await environment.repositories.votes.votes(spaceId: space.id)
        } catch {
            environment.report(error)
        }
    }

    func outcome(for vote: VoteDTO) -> VoteOutcome {
        VoteOutcome.make(
            vote: vote,
            viewerMemberId: environment?.currentMember?.id,
            partnerMemberId: environment?.partner?.id
        )
    }

    func startNew() {
        guard let environment, environment.premiumGate.require(.votes) else { return }
        isEditorPresented = true
    }

    func replace(_ vote: VoteDTO) {
        guard let index = votes.firstIndex(where: { $0.id == vote.id }) else { return }
        votes[index] = vote
    }
}
