import Foundation
import os

public actor RemoteChangeNotifier {
    public struct Audience: Sendable, Equatable {
        public var spaceId: UUID
        public var memberId: UUID
        public var partnerId: UUID?
        public var partnerName: String
        public var prefs: NotificationPrefs

        public init(
            spaceId: UUID,
            memberId: UUID,
            partnerId: UUID? = nil,
            partnerName: String = "",
            prefs: NotificationPrefs = .allEnabled
        ) {
            self.spaceId = spaceId
            self.memberId = memberId
            self.partnerId = partnerId
            self.partnerName = partnerName
            self.prefs = prefs
        }

        var viewer: RemoteChangeViewer {
            RemoteChangeViewer(memberId: memberId, partnerId: partnerId, partnerName: partnerName)
        }
    }

    public static let jointActionKey = "corbie.notifications.jointaction"

    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "remote-change")

    private let stack: CoreDataStack
    private let resolver: RemoteChangeResolver
    private let scheduler: NotificationScheduler
    private let defaults: UserDefaults
    private let reviewPrompt: ReviewPromptTracker

    private var audience: Audience?
    private var isObserving = false

    public init(
        stack: CoreDataStack,
        scheduler: NotificationScheduler,
        defaults: UserDefaults = .corbieShared
    ) {
        self.stack = stack
        self.scheduler = scheduler
        self.defaults = defaults
        reviewPrompt = ReviewPromptTracker(defaults: defaults)
        resolver = RemoteChangeResolver(stack: stack)
    }

    public var hasSeenJointAction: Bool {
        defaults.bool(forKey: RemoteChangeNotifier.jointActionKey)
    }

    public func update(audience: Audience?) {
        self.audience = audience
    }

    public func start() {
        guard isObserving == false else { return }
        isObserving = true
        stack.onRemoteChange { [weak self] records in
            guard let self else { return }
            Task { await self.handle(records) }
        }
    }

    public func stop() {
        isObserving = false
        stack.onRemoteChange(nil)
    }

    @discardableResult
    public func handle(_ records: [RemoteChangeRecord]) async -> [RemoteChangeAlert] {
        guard let audience else { return [] }
        let changes = await resolver.changes(for: records, spaceId: audience.spaceId)
        guard changes.isEmpty == false else { return [] }
        reviewPrompt.recordJointAction()
        guard await noteJointAction() else { return [] }
        let alerts = RemoteChangeClassifier.alerts(for: changes, viewer: audience.viewer)
        var delivered: [RemoteChangeAlert] = []
        for alert in alerts {
            do {
                guard try await scheduler.deliver(alert, prefs: audience.prefs) != nil else { continue }
                delivered.append(alert)
            } catch {
                RemoteChangeNotifier.log.error(
                    "remote alert \(alert.id, privacy: .public) was not delivered: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        return delivered
    }

    @discardableResult
    public func noteJointAction() async -> Bool {
        let granted = (try? await scheduler.requestAuthorizationIfNeeded()) ?? false
        defaults.set(true, forKey: RemoteChangeNotifier.jointActionKey)
        return granted
    }

    public func forgetJointAction() {
        defaults.removeObject(forKey: RemoteChangeNotifier.jointActionKey)
    }
}
