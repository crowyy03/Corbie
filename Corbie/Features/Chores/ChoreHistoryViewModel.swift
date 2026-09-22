import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class ChoreHistoryViewModel {
    private(set) var sets: [ChoreSetDTO] = []
    private(set) var hasLoaded = false

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
            hasLoaded = true
            return
        }
        do {
            sets = try await environment.repositories.chores
                .history(spaceId: space.id, viewerMemberId: environment.currentMember?.id)
                .filter { $0.appliedAt != nil }
        } catch {
            environment.report(error)
        }
        hasLoaded = true
    }
}
