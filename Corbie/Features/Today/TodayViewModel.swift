import CorbieCore
import Foundation
import Observation

struct TodayContext: Sendable {
    var space: SpaceDTO?
    var memberId: UUID?
    var prefs: NotificationPrefs

    init(
        space: SpaceDTO? = nil,
        memberId: UUID? = nil,
        prefs: NotificationPrefs = .allEnabled
    ) {
        self.space = space
        self.memberId = memberId
        self.prefs = prefs
    }
}

@MainActor
@Observable
final class TodayViewModel {
    private(set) var context = TodayContext()
    private(set) var feed = TodayFeed(day: Date())
    private(set) var hasLoaded = false
    private(set) var people: [PersonDTO] = []

    @ObservationIgnored var onError: ((any Error) -> Void)?
    @ObservationIgnored var onMemberChanged: ((MemberDTO) -> Void)?

    @ObservationIgnored private let repositories: Repositories
    @ObservationIgnored private let provider: TodayFeedProvider
    @ObservationIgnored private let unifiedTasks: UnifiedTaskProvider
    @ObservationIgnored private let notifications: NotificationScheduler
    @ObservationIgnored private let analytics: any AnalyticsRecording
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var reloadObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var hasRecordedOpen = false
    @ObservationIgnored private var hasRecordedRecap = false
    @ObservationIgnored private var recapStamp: RecapScheduleStamp?
    @ObservationIgnored private var recapFireDate: Date?

    init(
        repositories: Repositories,
        notifications: NotificationScheduler,
        analytics: any AnalyticsRecording,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repositories = repositories
        provider = TodayFeedProvider(repositories: repositories, calendar: calendar)
        unifiedTasks = UnifiedTaskProvider(repositories: repositories)
        self.notifications = notifications
        self.analytics = analytics
        self.calendar = calendar
        self.now = now
    }

    func apply(_ newContext: TodayContext) async {
        context = newContext
        await load()
    }

    func load() async {
        guard let space = context.space else {
            feed = TodayFeed(day: calendar.startOfDay(for: now()))
            hasLoaded = true
            return
        }
        do {
            people = try await repositories.people.people(spaceId: space.id)
            feed = try await provider.feed(space: space, viewerMemberId: context.memberId, now: now())
            hasLoaded = true
            recordOpen()
            recordRecap()
            await rescheduleRecapNotification(space: space)
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

    func toggle(_ entry: TodayEntry) async {
        guard let task = entry.task else { return }
        do {
            _ = try await unifiedTasks.toggleDone(task, by: context.memberId, at: now())
            if task.isDone == false {
                analytics.record(.taskDone)
            }
            await load()
        } catch {
            onError?(error)
        }
    }

    func take(_ task: UnifiedTask) async {
        guard let memberId = context.memberId else { return }
        do {
            _ = try await repositories.tasks.take(taskId: task.id, memberId: memberId, at: now())
            analytics.record(.taskTaken)
            await load()
        } catch {
            onError?(error)
        }
    }

    func openRecap() async {
        guard let memberId = context.memberId else { return }
        analytics.record(.recapOpened)
        do {
            let member = try await repositories.members.markRecapSeen(memberId: memberId, at: now())
            onMemberChanged?(member)
            await load()
        } catch {
            onError?(error)
        }
    }

    func open(_ route: Route, block: TodayBlock, in appState: AppState) {
        record(block: block)
        appState.open(route)
    }

    func record(block: TodayBlock) {
        analytics.record(.todayBlockTapped(block: block))
    }

    func record(quickAction: TodayQuickAction) {
        analytics.record(.todayQuickAction(kind: quickAction))
    }

    private func recordOpen() {
        guard hasRecordedOpen == false else { return }
        hasRecordedOpen = true
        analytics.record(.todayOpened)
    }

    private func recordRecap() {
        guard feed.recap != nil, hasRecordedRecap == false else { return }
        hasRecordedRecap = true
        analytics.record(.recapShown)
    }

    private func rescheduleRecapNotification(space: SpaceDTO) async {
        let stamp = RecapScheduleStamp(
            day: calendar.startOfDay(for: now()),
            isEnabled: context.prefs.weeklyRecap
        )
        guard recapStamp != stamp else { return }
        recapStamp = stamp
        do {
            let summary = try await provider.recapSummary(
                space: space,
                week: RecapSchedule.week(closing: now(), calendar: calendar)
            )
            let request = try await notifications.scheduleWeeklyRecap(
                summary,
                prefs: context.prefs,
                now: now()
            )
            guard let request, request.fireDate != recapFireDate else { return }
            recapFireDate = request.fireDate
            analytics.record(.recapNotificationSent)
        } catch {
            onError?(error)
        }
    }
}

private struct RecapScheduleStamp: Equatable {
    let day: Date
    let isEnabled: Bool
}
