import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

public final class IntentPersistence: @unchecked Sendable {
    public static let shared = IntentPersistence()

    private let lock = NSLock()
    private var storedController: PersistenceController?
    private var storedIdentity: MemberIdentity?
    #if DEBUG
    private let screenshotModeFlag: ScreenshotModeFlag?
    private let screenshotModeStore: ScreenshotModeStore
    private var screenshotMode: ScreenshotModeIntents?
    #endif

    #if DEBUG
    public convenience init() {
        self.init(screenshotModeFlag: ScreenshotModeFlag(), screenshotModeStore: ScreenshotModeStore())
    }

    public init(screenshotModeFlag: ScreenshotModeFlag?, screenshotModeStore: ScreenshotModeStore) {
        self.screenshotModeFlag = screenshotModeFlag
        self.screenshotModeStore = screenshotModeStore
    }
    #else
    public init() { }
    #endif

    public static func pinned(to controller: PersistenceController, identity: MemberIdentity) -> IntentPersistence {
        #if DEBUG
        let pinned = IntentPersistence(screenshotModeFlag: nil, screenshotModeStore: ScreenshotModeStore())
        #else
        let pinned = IntentPersistence()
        #endif
        pinned.use(controller: controller, identity: identity)
        return pinned
    }

    public func controller() -> PersistenceController {
        lock.lock()
        defer { lock.unlock() }
        #if DEBUG
        if let screenshotMode = currentScreenshotMode() { return screenshotMode.controller }
        #endif
        if let storedController { return storedController }
        let created = PersistenceController.appGroupWithoutMirroring(author: .widgets)
        storedController = created
        return created
    }

    public func identity() -> MemberIdentity {
        lock.lock()
        defer { lock.unlock() }
        #if DEBUG
        if let screenshotMode = currentScreenshotMode() { return screenshotMode.identity }
        #endif
        if let storedIdentity { return storedIdentity }
        let created = MemberIdentity()
        storedIdentity = created
        return created
    }

    public func use(controller: PersistenceController, identity: MemberIdentity? = nil) {
        lock.lock()
        defer { lock.unlock() }
        #if DEBUG
        if let session = controller.screenshotModeSession {
            screenshotMode = ScreenshotModeIntents(
                session: session,
                controller: controller,
                identity: identity ?? MemberIdentity(store: ScreenshotModeSecretStore.signedInAsAlex())
            )
            return
        }
        #endif
        storedController = controller
        if let identity {
            storedIdentity = identity
        }
    }

    public func reset() {
        lock.lock()
        storedController = nil
        storedIdentity = nil
        #if DEBUG
        screenshotMode = nil
        #endif
        lock.unlock()
    }

    public func currentMemberId() async throws -> UUID? {
        try await identity().currentMember(in: controller().stack)?.id
    }

    #if DEBUG
    private func currentScreenshotMode() -> ScreenshotModeIntents? {
        guard let session = screenshotModeFlag?.session else {
            screenshotMode = nil
            return nil
        }
        if let screenshotMode, screenshotMode.session == session { return screenshotMode }
        let opened = ScreenshotModeIntents(
            session: session,
            controller: screenshotModeStore.open(session: session, author: .widgets),
            identity: MemberIdentity(store: ScreenshotModeSecretStore.signedInAsAlex())
        )
        screenshotMode = opened
        return opened
    }
    #endif
}

#if DEBUG
private struct ScreenshotModeIntents {
    let session: String
    let controller: PersistenceController
    let identity: MemberIdentity
}
#endif

public final class WidgetReloader: @unchecked Sendable {
    public static let shared = WidgetReloader()

    private let lock = NSLock()
    private var token: (any NSObjectProtocol)?

    public init() { }

    public static func reloadNow() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    public func start(center: NotificationCenter = .default, reload: (@Sendable () -> Void)? = nil) {
        stop(center: center)
        let action: @Sendable () -> Void = reload ?? { WidgetReloader.reloadNow() }
        let observer = center.addObserver(
            forName: WidgetReloadRequest.notificationName,
            object: nil,
            queue: nil
        ) { _ in
            action()
        }
        lock.lock()
        token = observer
        lock.unlock()
    }

    public func stop(center: NotificationCenter = .default) {
        lock.lock()
        let observer = token
        token = nil
        lock.unlock()
        guard let observer else { return }
        center.removeObserver(observer)
    }
}
