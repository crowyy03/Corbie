import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class ChoreSplitOfferModel {
    private(set) var isOffered = false

    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var storeChanges: StoreChangeSubscription?

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
        guard storeChanges == nil else { return }
        storeChanges = environment.repositories.changes.subscribe { [weak self] in
            await self?.load()
        }
    }

    func load() async {
        guard let environment, let space = environment.space else {
            isOffered = false
            return
        }
        do {
            let sets = try await environment.repositories.chores.history(
                spaceId: space.id,
                viewerMemberId: environment.currentMember?.id
            )
            isOffered = sets.contains { $0.status == .applied } == false
        } catch {
            environment.report(error)
        }
    }
}
