import CoreData
import Foundation
import os

public final class CoreDataStack: @unchecked Sendable {
    public let container: NSPersistentContainer
    public let author: TransactionAuthor
    public let isCloudKitEnabled: Bool
    public let loadFailure: (any Error)?

    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "persistence")

    private let history: PersistentHistoryObserver?

    public var viewContext: NSManagedObjectContext { container.viewContext }

    public var cloudKitContainer: NSPersistentCloudKitContainer? {
        container as? NSPersistentCloudKitContainer
    }

    public init(author: TransactionAuthor = .app, cloudKitEnabled: Bool = true) {
        self.author = author
        isCloudKitEnabled = cloudKitEnabled
        let container = NSPersistentCloudKitContainer(name: CorbieModel.name, managedObjectModel: CorbieModel.shared)
        container.persistentStoreDescriptions = CoreDataStack.storeDescriptions(
            in: CoreDataStack.storesDirectory(),
            cloudKitEnabled: cloudKitEnabled
        )
        self.container = container
        loadFailure = CoreDataStack.load(container) ?? CoreDataStack.appGroupFailure()
        CoreDataStack.configure(container.viewContext, author: author)
        history = PersistentHistoryObserver(container: container, author: author)
        history?.start()
    }

    public init(storesIn directory: URL, author: TransactionAuthor = .tests) {
        self.author = author
        isCloudKitEnabled = false
        let container = NSPersistentContainer(name: CorbieModel.name, managedObjectModel: CorbieModel.shared)
        container.persistentStoreDescriptions = CoreDataStack.storeDescriptions(
            in: directory,
            cloudKitEnabled: false
        )
        self.container = container
        loadFailure = CoreDataStack.load(container)
        CoreDataStack.configure(container.viewContext, author: author)
        history = nil
    }

    public init(inMemoryAuthor author: TransactionAuthor = .tests) {
        self.author = author
        isCloudKitEnabled = false
        let container = NSPersistentContainer(name: CorbieModel.name, managedObjectModel: CorbieModel.shared)
        let description = NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        self.container = container
        loadFailure = CoreDataStack.load(container)
        CoreDataStack.configure(container.viewContext, author: author)
        history = nil
    }

    deinit {
        history?.stop()
    }

    public func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        CoreDataStack.configure(context, author: author)
        return context
    }

    public func onRemoteChange(_ handler: (@Sendable ([RemoteChangeRecord]) -> Void)?) {
        history?.setHandler(handler)
    }

    @discardableResult
    public func processHistory() throws -> Int {
        try history?.process() ?? 0
    }

    public func reloadStores() throws {
        if let failure = CoreDataStack.load(container) {
            throw CorbieError.persistence(failure.localizedDescription)
        }
        CoreDataStack.configure(container.viewContext, author: author)
    }

    public func store(for scope: StoreScope) -> NSPersistentStore? {
        let stores = container.persistentStoreCoordinator.persistentStores
        if let named = stores.first(where: { $0.url?.lastPathComponent == scope.fileName }) {
            return named
        }
        guard stores.count == 1, let only = stores.first, only.type == NSInMemoryStoreType else { return nil }
        return only
    }

    public func initializeCloudKitSchemaIfRequested(
        isRequested: Bool = ProcessInfo.processInfo.environment["CORBIE_INIT_SCHEMA"] == "1"
    ) throws {
        #if DEBUG
        guard isRequested else { return }
        guard let cloudKitContainer else {
            throw CorbieError.cloudKit("CloudKit container is not configured")
        }
        do {
            try cloudKitContainer.initializeCloudKitSchema(options: [])
        } catch {
            throw CorbieError.cloudKit(error.localizedDescription)
        }
        #endif
    }

    public static func storesDirectory() -> URL {
        let manager = FileManager.default
        if let group = appGroupDirectory(manager) {
            return group
        }
        let base = manager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = base.appendingPathComponent(CorbieModel.name, isDirectory: true)
        _ = makeDirectory(directory, manager: manager)
        return directory
    }

    public static var isAppGroupAvailable: Bool {
        appGroupDirectory(FileManager.default) != nil
    }

    private static func appGroupDirectory(_ manager: FileManager) -> URL? {
        guard let group = manager.containerURL(forSecurityApplicationGroupIdentifier: CorbieIdentifiers.appGroup),
              makeDirectory(group, manager: manager) else {
            return nil
        }
        return group
    }

    private static func appGroupFailure() -> (any Error)? {
        #if os(iOS)
        guard isAppGroupAvailable == false else { return nil }
        let message = "app group \(CorbieIdentifiers.appGroup) is unavailable, "
            + "the app and its extensions read different stores"
        log.error("\(message, privacy: .public)")
        return CorbieError.persistence(message)
        #else
        return nil
        #endif
    }

    private static func makeDirectory(_ url: URL, manager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        if manager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }
        do {
            try manager.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            log.error("cannot create store directory: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private static func storeDescriptions(in directory: URL, cloudKitEnabled: Bool) -> [NSPersistentStoreDescription] {
        [StoreScope.privateStore, StoreScope.sharedStore].map { scope in
            let description = NSPersistentStoreDescription(url: directory.appendingPathComponent(scope.fileName))
            description.shouldAddStoreAsynchronously = false
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            if cloudKitEnabled {
                let options = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: CorbieIdentifiers.cloudKitContainer
                )
                options.databaseScope = scope == .privateStore ? .private : .shared
                description.cloudKitContainerOptions = options
            }
            return description
        }
    }

    private static func load(_ container: NSPersistentContainer) -> (any Error)? {
        var failure: (any Error)?
        container.loadPersistentStores { _, error in
            if let error {
                failure = error
                log.error("store load failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        return failure
    }

    private static func configure(_ context: NSManagedObjectContext, author: TransactionAuthor) {
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        context.transactionAuthor = author.rawValue
        context.name = author.rawValue
    }
}
