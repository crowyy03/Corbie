import CoreData
import Foundation
import os

public struct StoreReset: @unchecked Sendable {
    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "persistence")
    private static let sidecarSuffixes = ["-wal", "-shm"]

    private let stack: CoreDataStack
    private let defaults: UserDefaults

    public init(stack: CoreDataStack, defaults: UserDefaults = .corbieShared) {
        self.stack = stack
        self.defaults = defaults
    }

    public func wipe() throws {
        let coordinator = stack.container.persistentStoreCoordinator
        stack.viewContext.reset()
        var files: [URL] = []
        for store in coordinator.persistentStores {
            let url = store.type == NSInMemoryStoreType ? nil : store.url
            let type = store.type
            do {
                try coordinator.remove(store)
            } catch {
                throw CorbieError.persistence(error.localizedDescription)
            }
            guard let url else { continue }
            files.append(url)
            do {
                try coordinator.destroyPersistentStore(at: url, ofType: type, options: nil)
            } catch {
                StoreReset.log.error("destroying \(url.lastPathComponent, privacy: .public) failed")
            }
        }
        StoreReset.removeFiles(at: files)
        clearHistoryTokens()
        try stack.reloadStores()
    }

    public func clearHistoryTokens() {
        for author in TransactionAuthor.allCases {
            defaults.removeObject(forKey: StoreReset.historyTokenKey(author: author))
        }
    }

    public static func historyTokenKey(author: TransactionAuthor) -> String {
        "history.token." + author.rawValue
    }

    @discardableResult
    public static func removeFiles(at urls: [URL]) -> [URL] {
        let manager = FileManager.default
        var removed: [URL] = []
        for url in urls {
            for candidate in [url] + sidecarSuffixes.map({ sidecar(url, suffix: $0) }) {
                guard manager.fileExists(atPath: candidate.path) else { continue }
                do {
                    try manager.removeItem(at: candidate)
                    removed.append(candidate)
                } catch {
                    log.error("removing \(candidate.lastPathComponent, privacy: .public) failed")
                }
            }
        }
        return removed
    }

    private static func sidecar(_ url: URL, suffix: String) -> URL {
        url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + suffix)
    }
}
