import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class TodayChoreModel {
    private(set) var state: ChoreSplitState = .notStarted

    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var reloadObserver: (any NSObjectProtocol)?

    init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    var isVisible: Bool { state.waitsForViewer }

    func start(_ environment: AppEnvironment, center: NotificationCenter = .default) async {
        self.environment = environment
        if reloadObserver == nil {
            reloadObserver = center.addObserver(
                forName: WidgetReloadRequest.notificationName,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor in await self?.load() }
            }
        }
        await load()
    }

    func stopObserving(center: NotificationCenter = .default) {
        guard let reloadObserver else { return }
        center.removeObserver(reloadObserver)
        self.reloadObserver = nil
    }

    func load() async {
        guard let environment, let space = environment.space else {
            state = .notStarted
            return
        }
        do {
            let sets = try await environment.repositories.chores.history(
                spaceId: space.id,
                viewerMemberId: environment.currentMember?.id
            )
            state = ChoreSplitState.make(
                sets: sets,
                viewerMemberId: environment.currentMember?.id,
                partnerMemberId: environment.partner?.id,
                now: now()
            )
        } catch {
            environment.report(error)
            return
        }
        await environment.replanPartnerProgressReminders([.choreSplitReady])
    }
}
