#if DEBUG
import Foundation

public struct ScreenshotModeLifecycle: Sendable {
    public let flag: ScreenshotModeFlag
    public let store: ScreenshotModeStore
    public let intents: IntentPersistence
    public let images: ScreenshotModeDemoImages
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let reloadWidgets: @Sendable () -> Void

    public init(
        flag: ScreenshotModeFlag = ScreenshotModeFlag(),
        store: ScreenshotModeStore = ScreenshotModeStore(),
        intents: IntentPersistence = .shared,
        images: ScreenshotModeDemoImages = .none,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() },
        reloadWidgets: @escaping @Sendable () -> Void = { WidgetReloader.reloadNow() }
    ) {
        self.flag = flag
        self.store = store
        self.intents = intents
        self.images = images
        self.calendar = calendar
        self.now = now
        self.reloadWidgets = reloadWidgets
    }

    private static let seedDayKeyPrefix = "screenshotMode.seedDay."

    public func enter() async throws -> ScreenshotModeSession {
        flag.turnOff()
        store.wipe()
        let session = open(ScreenshotModeFlag.newSession())
        let today = now()
        _ = try await ScreenshotModeSeeder(today: today, calendar: calendar, images: images)
            .seed(into: session.controller)
        store.defaults.set(calendar.startOfDay(for: today), forKey: seedDayKey(session.id))
        flag.turnOn(session: session.id)
        intents.use(controller: session.controller, identity: session.identity)
        reloadWidgets()
        return session
    }

    public func resume() async -> ScreenshotModeSession? {
        guard let id = flag.session, store.hasStore(for: id), wasSeededToday(id) else { return nil }
        let session = open(id)
        let alex = try? await session.controller.repositories.members.member(appleUserId: ScreenshotModeDemo.meAppleUserId)
        guard alex != nil else { return nil }
        intents.use(controller: session.controller, identity: session.identity)
        return session
    }

    public func leave(returningTo controller: PersistenceController, identity: MemberIdentity) {
        flag.turnOff()
        intents.use(controller: controller, identity: identity)
        reloadWidgets()
    }

    private func wasSeededToday(_ id: String) -> Bool {
        guard let seedDay = store.defaults.object(forKey: seedDayKey(id)) as? Date else { return false }
        return calendar.isDate(seedDay, inSameDayAs: now())
    }

    private func seedDayKey(_ id: String) -> String {
        ScreenshotModeLifecycle.seedDayKeyPrefix + id
    }

    private func open(_ id: String) -> ScreenshotModeSession {
        ScreenshotModeSession(
            id: id,
            controller: store.open(session: id, author: .app),
            defaults: store.defaults
        )
    }
}
#endif
