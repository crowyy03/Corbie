import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class TodayChoreModel {
    private(set) var state: ChoreSplitState = .notStarted

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var reloadObserver: (any NSObjectProtocol)?

    init(defaults: UserDefaults = .corbieShared, now: @escaping @Sendable () -> Date = { Date() }) {
        self.defaults = defaults
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
            await tellTheViewer(about: sets, in: environment)
        } catch {
            environment.report(error)
        }
    }

    private func tellTheViewer(about sets: [ChoreSetDTO], in environment: AppEnvironment) async {
        guard let plan = ChoreReminderPlanner.plan(
            sets: sets,
            viewerMemberId: environment.currentMember?.id,
            partnerMemberId: environment.partner?.id,
            partnerName: environment.partnerName,
            alreadyToldAbout: defaults.string(forKey: ChoreReminderPlanner.toldKey)
        ) else { return }
        defaults.set(plan.setId.uuidString, forKey: ChoreReminderPlanner.toldKey)
        do {
            try await environment.notifications.scheduleChoreSplitReady(
                setId: plan.setId,
                partnerName: plan.partnerName,
                prefs: environment.currentMember?.notificationPrefs ?? .allEnabled,
                now: now()
            )
        } catch {
            environment.report(error)
        }
    }
}
