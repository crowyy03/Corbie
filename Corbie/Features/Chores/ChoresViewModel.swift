import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class ChoresViewModel {
    static let nudgeKey = "corbie.chore.nudged"

    private(set) var sets: [ChoreSetDTO] = []
    private(set) var hasLoaded = false
    private(set) var isWorking = false

    @ObservationIgnored var onError: ((any Error) -> Void)?

    @ObservationIgnored private let repository: any ChoreRepository
    @ObservationIgnored private let catalog: ChoreCatalog
    @ObservationIgnored private let analytics: any AnalyticsRecording
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private(set) var context = ChoresContext()

    init(
        repository: any ChoreRepository,
        catalog: ChoreCatalog = .bundled,
        analytics: any AnalyticsRecording,
        calendar: Calendar = .current,
        defaults: UserDefaults = .corbieShared,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.catalog = catalog
        self.analytics = analytics
        self.calendar = calendar
        self.defaults = defaults
        self.now = now
    }

    var state: ChoreSplitState {
        ChoreSplitState.make(
            sets: sets,
            viewerMemberId: context.memberId,
            partnerMemberId: context.partnerId,
            now: now()
        )
    }

    var openSet: ChoreSetDTO? { sets.first { $0.status != .applied } }

    var lastAppliedSet: ChoreSetDTO? { sets.first { $0.status == .applied } }

    func apply(_ context: ChoresContext) async {
        self.context = context
        await load()
    }

    func load() async {
        guard let spaceId = context.spaceId else {
            sets = []
            hasLoaded = true
            return
        }
        do {
            sets = try await repository.history(spaceId: spaceId, viewerMemberId: context.memberId)
        } catch {
            onError?(error)
        }
        hasLoaded = true
    }

    func start() async {
        guard let spaceId = context.spaceId, isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let started = try await repository.startSet(
                spaceId: spaceId,
                catalogIds: catalog.preselectedIds,
                memberId: context.memberId,
                at: now()
            )
            analytics.record(.choreFlowStarted)
            replace(started)
        } catch {
            onError?(error)
        }
    }

    func resplit() async {
        guard let spaceId = context.spaceId, let previous = lastAppliedSet, isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let included = previous.includedItems
            var fresh = try await repository.startSet(
                spaceId: spaceId,
                catalogIds: included.compactMap(\.catalogId),
                memberId: context.memberId,
                at: now()
            )
            for custom in included.filter(\.isCustom) {
                fresh = try await repository.addItem(
                    setId: fresh.id,
                    draft: ChoreItemDraft(
                        title: custom.title,
                        frequency: custom.frequency,
                        addedByMemberId: context.memberId
                    )
                )
            }
            analytics.record(.choreResplit)
            replace(fresh)
        } catch {
            onError?(error)
        }
    }

    func reveal() async {
        guard let open = openSet, isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            replace(try await repository.reveal(setId: open.id, at: now()))
        } catch {
            onError?(error)
        }
    }

    var canNudge: Bool {
        guard let last = defaults.object(forKey: ChoresViewModel.nudgeKey) as? Date else { return true }
        return calendar.isDate(last, inSameDayAs: now()) == false
    }

    func nudge() -> Bool {
        guard canNudge else { return false }
        defaults.set(now(), forKey: ChoresViewModel.nudgeKey)
        return true
    }

    func replace(_ set: ChoreSetDTO) {
        guard let index = sets.firstIndex(where: { $0.id == set.id }) else {
            sets.insert(set, at: 0)
            return
        }
        sets[index] = set
    }
}
