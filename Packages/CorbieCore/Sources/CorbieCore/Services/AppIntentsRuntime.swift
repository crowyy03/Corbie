import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

public final class IntentPersistence: @unchecked Sendable {
    public static let shared = IntentPersistence()

    private let lock = NSLock()
    private var storedController: PersistenceController?
    private var storedIdentity: MemberIdentity?

    public init() { }

    public func controller() -> PersistenceController {
        lock.lock()
        defer { lock.unlock() }
        if let storedController { return storedController }
        let created = PersistenceController.cloudKit(author: .widgets)
        storedController = created
        return created
    }

    public func identity() -> MemberIdentity {
        lock.lock()
        defer { lock.unlock() }
        if let storedIdentity { return storedIdentity }
        let created = MemberIdentity()
        storedIdentity = created
        return created
    }

    public func use(controller: PersistenceController, identity: MemberIdentity? = nil) {
        lock.lock()
        storedController = controller
        if let identity {
            storedIdentity = identity
        }
        lock.unlock()
    }

    public func reset() {
        lock.lock()
        storedController = nil
        storedIdentity = nil
        lock.unlock()
    }

    public func currentMemberId() async throws -> UUID? {
        try await identity().currentMember(in: controller().stack)?.id
    }
}

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
