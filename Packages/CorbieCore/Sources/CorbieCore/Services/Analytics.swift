import Foundation

public protocol AnalyticsRecording: Sendable {
    func record(_ event: AnalyticsEvent)
}

public actor Analytics: AnalyticsRecording {
    public static let maxEventsPerBatch = 50
    public static let flushThreshold = 20
    public static let flushInterval: TimeInterval = 60
    public static let queueLimit = 500

    public static let shared = Analytics()

    private let client: APIClient
    private let storage: any AnalyticsStorage
    private let appVersion: String
    private let localeIdentifier: String
    private let threshold: Int
    private let interval: TimeInterval
    private let now: @Sendable () -> Date

    private var queue: [AnalyticsEventPayload] = []
    private var didLoad = false
    private var ticker: Task<Void, Never>?

    public init(
        client: APIClient? = nil,
        storage: any AnalyticsStorage = FileAnalyticsStorage(),
        identity: AnonymousIdentity = .shared,
        appVersion: String = AppVersion.current(),
        locale: Locale = .current,
        threshold: Int = Analytics.flushThreshold,
        interval: TimeInterval = Analytics.flushInterval,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client ?? APIClient(identity: identity)
        self.storage = storage
        self.appVersion = appVersion
        localeIdentifier = locale.identifier
        self.threshold = max(1, threshold)
        self.interval = max(1, interval)
        self.now = now
    }

    public nonisolated func record(_ event: AnalyticsEvent) {
        Task { await track(event) }
    }

    public func track(_ event: AnalyticsEvent) async {
        loadIfNeeded()
        queue.append(
            AnalyticsEventPayload(
                name: event.name,
                props: event.props,
                ts: now(),
                appVersion: appVersion,
                locale: localeIdentifier
            )
        )
        if queue.count > Analytics.queueLimit {
            queue.removeFirst(queue.count - Analytics.queueLimit)
        }
        storage.save(queue)
        if queue.count >= threshold {
            await flush()
        }
    }

    public func flush() async {
        loadIfNeeded()
        while queue.isEmpty == false {
            let batch = Array(queue.prefix(Analytics.maxEventsPerBatch))
            do {
                try await client.events(batch)
            } catch let failure as APIError where isPermanent(failure) {
                queue.removeFirst(batch.count)
                storage.save(queue)
                continue
            } catch {
                return
            }
            queue.removeFirst(batch.count)
            storage.save(queue)
        }
    }

    public var pendingCount: Int {
        loadIfNeeded()
        return queue.count
    }

    public var pending: [AnalyticsEventPayload] {
        loadIfNeeded()
        return queue
    }

    public func start() {
        guard ticker == nil else { return }
        let seconds = interval
        ticker = Task { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                if Task.isCancelled { return }
                await self?.flush()
            }
        }
    }

    public func stop() {
        ticker?.cancel()
        ticker = nil
    }

    private func loadIfNeeded() {
        guard didLoad == false else { return }
        didLoad = true
        queue = storage.load()
    }

    private func isPermanent(_ failure: APIError) -> Bool {
        guard let status = failure.status else { return false }
        return (400 ..< 500).contains(status) && status != 429 && status != 401
    }
}
