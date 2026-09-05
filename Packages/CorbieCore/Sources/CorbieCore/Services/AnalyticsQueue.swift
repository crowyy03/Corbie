import Foundation

public protocol AnalyticsStorage: Sendable {
    func load() -> [AnalyticsEventPayload]
    func save(_ events: [AnalyticsEventPayload])
}

public enum AnalyticsPaths {
    public static let directoryName = "Analytics"

    public static func containerDirectory(appGroup: String = CorbieIdentifiers.appGroup) -> URL {
        let manager = FileManager.default
        let base = manager.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? manager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent(directoryName, isDirectory: true)
    }
}

public struct FileAnalyticsStorage: AnalyticsStorage {
    public static let fileName = "queue.json"

    private let fileURL: URL

    public init(
        directory: URL = AnalyticsPaths.containerDirectory(),
        fileName: String = FileAnalyticsStorage.fileName
    ) {
        fileURL = directory.appendingPathComponent(fileName, isDirectory: false)
    }

    public func load() -> [AnalyticsEventPayload] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? CorbieJSON.decoder.decode([AnalyticsEventPayload].self, from: data)) ?? []
    }

    public func save(_ events: [AnalyticsEventPayload]) {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard events.isEmpty == false else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        guard let data = try? CorbieJSON.encoder.encode(events) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

public final class InMemoryAnalyticsStorage: AnalyticsStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var events: [AnalyticsEventPayload]

    public init(events: [AnalyticsEventPayload] = []) {
        self.events = events
    }

    public func load() -> [AnalyticsEventPayload] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    public func save(_ events: [AnalyticsEventPayload]) {
        lock.lock()
        self.events = events
        lock.unlock()
    }
}
