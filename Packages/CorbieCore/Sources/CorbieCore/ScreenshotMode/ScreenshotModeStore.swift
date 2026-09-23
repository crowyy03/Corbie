#if DEBUG
import Foundation
import os

public struct ScreenshotModeStore: @unchecked Sendable {
    public static let directoryName = "ScreenshotMode"
    public static let defaultsSuiteName = "app.corbie.screenshot-mode"

    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "screenshot-mode")

    public let root: URL
    public let defaultsSuiteName: String
    public let defaults: UserDefaults

    public init(
        root: URL = ScreenshotModeStore.defaultRoot(),
        defaultsSuiteName: String = ScreenshotModeStore.defaultsSuiteName
    ) {
        self.root = root
        self.defaultsSuiteName = defaultsSuiteName
        defaults = UserDefaults(suiteName: defaultsSuiteName) ?? UserDefaults()
    }

    public static func defaultRoot() -> URL {
        CoreDataStack.storesDirectory().appendingPathComponent(directoryName, isDirectory: true)
    }

    public func directory(for session: String) -> URL {
        root.appendingPathComponent(session, isDirectory: true)
    }

    public func hasStore(for session: String) -> Bool {
        let file = directory(for: session).appendingPathComponent(StoreScope.privateStore.fileName)
        return FileManager.default.fileExists(atPath: file.path)
    }

    public func open(session: String, author: TransactionAuthor) -> PersistenceController {
        let directory = directory(for: session)
        prepare(directory)
        defaults.removeObject(forKey: StoreReset.historyTokenKey(author: author))
        let stack = CoreDataStack(storesIn: directory, author: author, historyDefaults: defaults)
        return PersistenceController(stack: stack, screenshotModeSession: session)
    }

    public func wipe() {
        let manager = FileManager.default
        if manager.fileExists(atPath: root.path) {
            do {
                try manager.removeItem(at: root)
            } catch {
                ScreenshotModeStore.log.error("wiping the demo stores failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    private func prepare(_ directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var excluded = root
            try excluded.setResourceValues(values)
        } catch {
            ScreenshotModeStore.log.error("preparing the demo directory failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

public struct ScreenshotModeSession: @unchecked Sendable {
    public let id: String
    public let controller: PersistenceController
    public let secrets: ScreenshotModeSecretStore
    public let defaults: UserDefaults

    public init(id: String, controller: PersistenceController, defaults: UserDefaults) {
        self.id = id
        self.controller = controller
        self.defaults = defaults
        secrets = ScreenshotModeSecretStore.signedInAsAlex()
    }

    public var identity: MemberIdentity { MemberIdentity(store: secrets) }
}

public final class ScreenshotModeSecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    public init() { }

    public static func signedInAsAlex() -> ScreenshotModeSecretStore {
        let store = ScreenshotModeSecretStore()
        try? store.setString(ScreenshotModeDemo.meAppleUserId, for: MemberIdentity.appleUserIDKey)
        return store
    }

    public func data(for key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    public func setData(_ value: Data, for key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
    }

    public func removeValue(for key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values[key] = nil
    }
}
#endif
