import CorbieCore
import Foundation
import Observation

enum TaskFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case mine
    case partner
    case free

    var id: String { rawValue }
}

struct TasksContext: Equatable, Sendable {
    var spaceId: UUID?
    var memberId: UUID?
    var partnerId: UUID?
    var partnerName: String?
    var prefs: NotificationPrefs

    init(
        spaceId: UUID? = nil,
        memberId: UUID? = nil,
        partnerId: UUID? = nil,
        partnerName: String? = nil,
        prefs: NotificationPrefs = .allEnabled
    ) {
        self.spaceId = spaceId
        self.memberId = memberId
        self.partnerId = partnerId
        self.partnerName = partnerName
        self.prefs = prefs
    }
}

struct TaskGroup: Identifiable, Equatable {
    enum Kind: String, Sendable {
        case inProgress
        case free
    }

    let kind: Kind
    let tasks: [TaskDTO]

    var id: String { kind.rawValue }
}

@MainActor
@Observable
final class TasksViewModel {
    var filter: TaskFilter = .all
    private(set) var context = TasksContext()
    private(set) var tasks: [TaskDTO] = []
    private(set) var counts = TaskCounts()
    private(set) var hasLoaded = false

    @ObservationIgnored var onError: ((any Error) -> Void)?

    @ObservationIgnored private let repository: any TaskRepository
    @ObservationIgnored private let notifications: TaskDueNotifications
    @ObservationIgnored private let analytics: any AnalyticsRecording
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var reloadObserver: (any NSObjectProtocol)?

    init(
        repository: any TaskRepository,
        notifications: TaskDueNotifications,
        analytics: any AnalyticsRecording,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.notifications = notifications
        self.analytics = analytics
        self.now = now
    }

    var availableFilters: [TaskFilter] {
        var result: [TaskFilter] = [.all, .mine]
        if context.partnerId != nil {
            result.append(.partner)
        }
        result.append(.free)
        return result
    }

    var groups: [TaskGroup] {
        let visible = tasks(matching: filter)
        var result: [TaskGroup] = []
        let assigned = visible.filter { $0.isFree == false }
        if assigned.isEmpty == false {
            result.append(TaskGroup(kind: .inProgress, tasks: assigned))
        }
        let free = visible.filter(\.isFree)
        if free.isEmpty == false {
            result.append(TaskGroup(kind: .free, tasks: free))
        }
        return result
    }

    var isEmpty: Bool { tasks.isEmpty }

    func tasks(matching filter: TaskFilter) -> [TaskDTO] {
        switch filter {
        case .all:
            return tasks
        case .mine:
            guard let memberId = context.memberId else { return [] }
            return tasks.filter { $0.assigneeMemberId == memberId }
        case .partner:
            guard let partnerId = context.partnerId else { return [] }
            return tasks.filter { $0.assigneeMemberId == partnerId }
        case .free:
            return tasks.filter(\.isFree)
        }
    }

    func count(for filter: TaskFilter) -> Int {
        switch filter {
        case .all:
            return counts.all
        case .mine:
            return counts.mine
        case .partner:
            return counts.partner
        case .free:
            return counts.free
        }
    }

    func label(for filter: TaskFilter) -> String {
        switch filter {
        case .all:
            return String(localized: "tasks.filter.all")
        case .mine:
            return String(localized: "tasks.filter.mine")
        case .partner:
            return context.partnerName ?? String(localized: "member.name.partner")
        case .free:
            return String(localized: "tasks.filter.free")
        }
    }

    func canDelete(_ task: TaskDTO) -> Bool {
        guard let memberId = context.memberId else { return false }
        guard let author = task.createdByMemberId else { return true }
        return author == memberId
    }

    func apply(_ newContext: TasksContext) async {
        let changed = newContext != context
        context = newContext
        if availableFilters.contains(filter) == false {
            filter = .all
        }
        if changed || hasLoaded == false {
            await load()
        }
    }

    func load() async {
        guard let spaceId = context.spaceId else {
            tasks = []
            counts = TaskCounts()
            hasLoaded = true
            return
        }
        do {
            tasks = try await repository.tasks(TaskQuery(spaceId: spaceId))
            counts = try await repository.counts(
                spaceId: spaceId,
                memberId: context.memberId,
                partnerId: context.partnerId
            )
            hasLoaded = true
        } catch {
            onError?(error)
        }
    }

    func startObserving(center: NotificationCenter = .default) {
        guard reloadObserver == nil else { return }
        reloadObserver = center.addObserver(
            forName: WidgetReloadRequest.notificationName,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.load()
            }
        }
    }

    func stopObserving(center: NotificationCenter = .default) {
        guard let reloadObserver else { return }
        center.removeObserver(reloadObserver)
        self.reloadObserver = nil
    }

    func take(_ task: TaskDTO) async {
        guard let memberId = context.memberId else { return }
        do {
            _ = try await repository.take(taskId: task.id, memberId: memberId, at: now())
            analytics.record(.taskTaken)
            await load()
        } catch {
            onError?(error)
        }
    }

    func handBack(_ task: TaskDTO) async {
        do {
            _ = try await repository.handBack(taskId: task.id)
            analytics.record(.taskHandedBack)
            await load()
        } catch {
            onError?(error)
        }
    }

    func markDone(_ task: TaskDTO) async {
        do {
            let completion = try await repository.markDone(
                taskId: task.id,
                memberId: context.memberId ?? task.assigneeMemberId,
                at: now()
            )
            analytics.record(.taskDone)
            await notifications.cancel(taskId: task.id)
            if completion.isNextOccurrenceDue {
                let next = try await repository.createNextOccurrence(
                    of: task.id,
                    dueAt: completion.nextOccurrenceDueAt
                )
                await notifications.sync(task: next, prefs: context.prefs, now: now())
            }
            await load()
        } catch {
            onError?(error)
        }
    }

    func delete(_ task: TaskDTO) async {
        do {
            try await repository.delete(id: task.id)
            await notifications.cancel(taskId: task.id)
            await load()
        } catch {
            onError?(error)
        }
    }
}
