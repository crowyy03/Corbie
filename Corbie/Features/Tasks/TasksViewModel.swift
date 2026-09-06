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

enum TaskFolderSelection: Hashable, Sendable {
    case all
    case folder(UUID)
}

enum TasksFolderMode: String, Hashable, Sendable {
    case list
    case map
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

enum TaskListItem: Identifiable, Equatable, Sendable {
    case task(TaskDTO)
    case goalStep(UnifiedTask)

    var id: UUID {
        switch self {
        case let .task(task): return task.id
        case let .goalStep(step): return step.id
        }
    }

    var title: String {
        switch self {
        case let .task(task): return task.title
        case let .goalStep(step): return step.title
        }
    }

    var assigneeMemberId: UUID? {
        switch self {
        case let .task(task): return task.assigneeMemberId
        case let .goalStep(step): return step.assigneeMemberId
        }
    }

    var isDone: Bool {
        switch self {
        case let .task(task): return task.isDone
        case let .goalStep(step): return step.isDone
        }
    }

    var isFree: Bool { assigneeMemberId == nil }

    var goalTitle: String? {
        switch self {
        case .task: return nil
        case let .goalStep(step): return step.goalTitle
        }
    }

    var task: TaskDTO? {
        switch self {
        case let .task(task): return task
        case .goalStep: return nil
        }
    }
}

struct TaskGroup: Identifiable, Equatable {
    enum Kind: String, Sendable {
        case inProgress
        case free
    }

    let kind: Kind
    let items: [TaskListItem]

    var id: String { kind.rawValue }
}

@MainActor
@Observable
final class TasksViewModel {
    var filter: TaskFilter = .all
    private(set) var folderSelection: TaskFolderSelection = .all
    private(set) var mode: TasksFolderMode = .list
    private(set) var context = TasksContext()
    private(set) var items: [TaskListItem] = []
    private(set) var folders: [TaskFolderDTO] = []
    private(set) var hasLoaded = false

    @ObservationIgnored var onError: ((any Error) -> Void)?

    @ObservationIgnored private let repository: any TaskRepository
    @ObservationIgnored private let provider: UnifiedTaskProvider
    @ObservationIgnored private let notifications: TaskDueNotifications
    @ObservationIgnored private let analytics: any AnalyticsRecording
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var reloadObserver: (any NSObjectProtocol)?

    init(
        repository: any TaskRepository,
        provider: UnifiedTaskProvider,
        notifications: TaskDueNotifications,
        analytics: any AnalyticsRecording,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.provider = provider
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

    var counts: TaskCounts {
        let open = items.filter { $0.isDone == false }
        return TaskCounts(
            all: open.count,
            mine: context.memberId.map { id in open.filter { $0.assigneeMemberId == id }.count } ?? 0,
            partner: context.partnerId.map { id in open.filter { $0.assigneeMemberId == id }.count } ?? 0,
            free: open.filter(\.isFree).count
        )
    }

    var visibleItems: [TaskListItem] {
        items(matching: filter)
    }

    var groups: [TaskGroup] {
        let visible = visibleItems
        var result: [TaskGroup] = []
        let assigned = visible.filter { $0.isFree == false }
        if assigned.isEmpty == false {
            result.append(TaskGroup(kind: .inProgress, items: assigned))
        }
        let free = visible.filter(\.isFree)
        if free.isEmpty == false {
            result.append(TaskGroup(kind: .free, items: free))
        }
        return result
    }

    var isEmpty: Bool { items.isEmpty }

    var selectedFolder: TaskFolderDTO? {
        guard case let .folder(id) = folderSelection else { return nil }
        return folders.first { $0.id == id }
    }

    var showsClearDone: Bool {
        selectedFolder?.isPinnedShopping == true && items.contains(where: \.isDone)
    }

    var placedTasks: [TaskDTO] {
        items.compactMap(\.task).filter(\.hasPlace)
    }

    var showsMapToggle: Bool {
        selectedFolder != nil && placedTasks.isEmpty == false
    }

    func items(matching filter: TaskFilter) -> [TaskListItem] {
        switch filter {
        case .all:
            return items
        case .mine:
            guard let memberId = context.memberId else { return [] }
            return items.filter { $0.assigneeMemberId == memberId }
        case .partner:
            guard let partnerId = context.partnerId else { return [] }
            return items.filter { $0.assigneeMemberId == partnerId }
        case .free:
            return items.filter(\.isFree)
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

    func canDelete(_ item: TaskListItem) -> Bool {
        guard let task = item.task, let memberId = context.memberId else { return false }
        guard let author = task.createdByMemberId else { return true }
        return author == memberId
    }

    func canTick(_ item: TaskListItem) -> Bool {
        guard let task = item.task, let folderId = task.folderId else { return true }
        guard let folder = folders.first(where: { $0.id == folderId }), folder.anyoneCanCheck == false else {
            return true
        }
        guard let memberId = context.memberId,
              let author = task.createdByMemberId ?? folder.createdByMemberId
        else {
            return false
        }
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

    func select(_ selection: TaskFolderSelection) async {
        guard selection != folderSelection else { return }
        folderSelection = selection
        mode = .list
        await load()
    }

    func toggleMode() {
        mode = mode == .list ? .map : .list
        guard mode == .map else { return }
        analytics.record(.folderMapOpened)
    }

    func load() async {
        guard let spaceId = context.spaceId else {
            items = []
            folders = []
            hasLoaded = true
            return
        }
        do {
            folders = try await repository.folders(spaceId: spaceId)
            if case let .folder(id) = folderSelection, folders.contains(where: { $0.id == id }) == false {
                folderSelection = .all
                mode = .list
            }
            items = try await loadItems(spaceId: spaceId)
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

    func take(_ item: TaskListItem) async {
        guard let task = item.task, let memberId = context.memberId else { return }
        do {
            _ = try await repository.take(taskId: task.id, memberId: memberId, at: now())
            analytics.record(.taskTaken)
            await load()
        } catch {
            onError?(error)
        }
    }

    func handBack(_ item: TaskListItem) async {
        guard let task = item.task else { return }
        do {
            _ = try await repository.handBack(taskId: task.id)
            analytics.record(.taskHandedBack)
            await load()
        } catch {
            onError?(error)
        }
    }

    func toggleDone(_ item: TaskListItem) async {
        switch item {
        case let .task(task):
            if task.isDone {
                await reopen(task)
            } else {
                await complete(task)
            }
        case let .goalStep(step):
            await toggleStep(step)
        }
    }

    func delete(_ item: TaskListItem) async {
        guard let task = item.task else { return }
        do {
            try await repository.delete(id: task.id)
            await notifications.cancel(taskId: task.id)
            await load()
        } catch {
            onError?(error)
        }
    }

    func move(_ item: TaskListItem, to folderId: UUID?) async {
        guard let task = item.task, task.folderId != folderId else { return }
        do {
            _ = try await repository.move(taskId: task.id, toFolder: folderId)
            await load()
        } catch {
            onError?(error)
        }
    }

    func clearDone() async {
        guard let folder = selectedFolder else { return }
        do {
            _ = try await repository.clearDone(folderId: folder.id)
            await load()
        } catch {
            onError?(error)
        }
    }

    func deleteSelectedFolder() async {
        guard let folder = selectedFolder, folder.isPinnedShopping == false else { return }
        do {
            try await repository.deleteFolder(id: folder.id)
            folderSelection = .all
            mode = .list
            await load()
        } catch {
            onError?(error)
        }
    }

    private func loadItems(spaceId: UUID) async throws -> [TaskListItem] {
        switch folderSelection {
        case .all:
            let query = TaskQuery(spaceId: spaceId, folder: .none)
            let tasks = try await repository.tasks(query)
            let byId = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            return try await provider.unifiedTasks(query).map { unified in
                byId[unified.id].map(TaskListItem.task) ?? .goalStep(unified)
            }
        case let .folder(id):
            let query = TaskQuery(spaceId: spaceId, done: .any, folder: .folder(id))
            return try await repository.tasks(query).map(TaskListItem.task)
        }
    }

    private func complete(_ task: TaskDTO) async {
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

    private func reopen(_ task: TaskDTO) async {
        do {
            let reopened = try await repository.setDone(
                taskId: task.id,
                isDone: false,
                memberId: context.memberId,
                at: now()
            )
            await notifications.sync(task: reopened, prefs: context.prefs, now: now())
            await load()
        } catch {
            onError?(error)
        }
    }

    private func toggleStep(_ step: UnifiedTask) async {
        do {
            let updated = try await provider.toggleDone(step, by: context.memberId, at: now())
            if updated.isDone {
                analytics.record(.goalStepDone)
            }
            await load()
        } catch {
            onError?(error)
        }
    }
}
