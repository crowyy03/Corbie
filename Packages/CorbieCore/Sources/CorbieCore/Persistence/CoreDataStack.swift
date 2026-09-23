import CoreData
import Foundation
import os

public enum StoreMirroring: Sendable, Equatable {
    case cloudKit
    case disabled
}

public final class CoreDataStack: @unchecked Sendable {
    public let container: NSPersistentContainer
    public let author: TransactionAuthor
    public let mirroring: StoreMirroring
    public let loadFailure: (any Error)?
    public let changes: StoreChanges

    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "persistence")

    private let history: PersistentHistoryObserver?
    private let runningImports: CloudKitRunningImports?
    private let exportLedger: CloudKitExportLedger?
    private let cloudKitActivity: CloudKitActivityLog?

    public var viewContext: NSManagedObjectContext { container.viewContext }

    public var cloudKitContainer: NSPersistentCloudKitContainer? {
        guard mirroring == .cloudKit else { return nil }
        return container as? NSPersistentCloudKitContainer
    }

    public convenience init(appGroupAuthor author: TransactionAuthor, mirroring: StoreMirroring) {
        self.init(
            directory: CoreDataStack.storesDirectory(),
            author: author,
            mirroring: mirroring,
            historyDefaults: .corbieShared,
            requiresAppGroup: true
        )
    }

    public convenience init(
        storesIn directory: URL,
        author: TransactionAuthor = .tests,
        historyDefaults: UserDefaults? = nil
    ) {
        self.init(
            directory: directory,
            author: author,
            mirroring: .disabled,
            historyDefaults: historyDefaults,
            requiresAppGroup: false
        )
    }

    init(
        directory: URL,
        author: TransactionAuthor,
        mirroring: StoreMirroring,
        historyDefaults: UserDefaults?,
        requiresAppGroup: Bool
    ) {
        self.author = author
        self.mirroring = mirroring
        runningImports = mirroring == .cloudKit ? CloudKitRunningImports() : nil
        let exportLedger = mirroring == .cloudKit ? historyDefaults.map { CloudKitExportLedger(defaults: $0) } : nil
        self.exportLedger = exportLedger
        let container = CoreDataStack.makeContainer(mirroring: mirroring)
        container.persistentStoreDescriptions = CoreDataStack.storeDescriptions(in: directory, mirroring: mirroring)
        self.container = container
        let cloudKitActivity = mirroring == .cloudKit
            ? historyDefaults.flatMap { CloudKitActivityLog.mirroring(container, defaults: $0) }
            : nil
        self.cloudKitActivity = cloudKitActivity
        let appGroupFailure = requiresAppGroup ? CoreDataStack.appGroupFailure() : nil
        loadFailure = CoreDataStack.load(container) ?? appGroupFailure
        CoreDataStack.configure(container.viewContext, author: author)
        let changes = StoreChanges()
        self.changes = changes
        history = historyDefaults.map { defaults in
            PersistentHistoryObserver(
                container: container,
                author: author,
                defaults: defaults,
                changes: changes,
                cleanupCutoff: exportLedger.map(CoreDataStack.cleanupAfterUpload),
                holdsRecordsUntilHandled: mirroring == .cloudKit
            )
        }
        history?.start()
        cloudKitActivity?.start()
    }

    public init(inMemoryAuthor author: TransactionAuthor = .tests) {
        self.author = author
        mirroring = .disabled
        let container = NSPersistentContainer(name: CorbieModel.name, managedObjectModel: CorbieModel.shared)
        let description = NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        self.container = container
        loadFailure = CoreDataStack.load(container)
        CoreDataStack.configure(container.viewContext, author: author)
        changes = StoreChanges()
        history = nil
        runningImports = nil
        exportLedger = nil
        cloudKitActivity = nil
    }

    private static func cleanupAfterUpload(_ ledger: CloudKitExportLedger) -> PersistentHistoryObserver.CleanupCutoff {
        { storeIdentifiers in
            HistoryCleanupRule.cutoff(
                now: Date(),
                storeIdentifiers: storeIdentifiers,
                lastUploadStarts: ledger.lastUploadStarts
            )
        }
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

    public func watchUpload(of scope: StoreScope) -> CloudKitUploadWatch {
        guard mirroring == .cloudKit, let identifier = store(for: scope)?.identifier else {
            return CloudKitUploadWatch(wait: nil)
        }
        return CloudKitUploadWatch(
            wait: CloudKitSyncWait(kind: .exporting, storeIdentifier: identifier, startedAtOrAfter: Date())
        )
    }

    func importWait(for scope: StoreScope?, arrivedAt: Date) -> CloudKitSyncWait? {
        guard let runningImports else { return nil }
        let storeIdentifier = scope.flatMap { store(for: $0)?.identifier }
        let running = runningImports.earliestStart(storeIdentifier: storeIdentifier) ?? arrivedAt
        return CloudKitSyncWait(
            kind: .importing,
            storeIdentifier: storeIdentifier,
            startedAtOrAfter: min(running, arrivedAt)
        )
    }

    public func watchImport(intoStoreHolding spaceId: UUID) async -> CloudKitImportWatch? {
        guard runningImports != nil else { return nil }
        let scope = await scope(holdingSpace: spaceId)
        return importWait(for: scope, arrivedAt: Date()).map(CloudKitImportWatch.init)
    }

    func scope(holdingSpace spaceId: UUID) async -> StoreScope? {
        let context = newBackgroundContext()
        let storeIdentifier = await context.perform {
            let space: Space? = try? ManagedFetch.first(Space.entityName, id: spaceId, in: context)
            return space?.objectID.persistentStore?.identifier
        }
        guard let storeIdentifier else { return nil }
        return StoreScope.allCases.first { store(for: $0)?.identifier == storeIdentifier }
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

    private static func makeContainer(mirroring: StoreMirroring) -> NSPersistentContainer {
        switch mirroring {
        case .cloudKit:
            return NSPersistentCloudKitContainer(name: CorbieModel.name, managedObjectModel: CorbieModel.shared)
        case .disabled:
            return NSPersistentContainer(name: CorbieModel.name, managedObjectModel: CorbieModel.shared)
        }
    }

    static func storeDescriptions(in directory: URL, mirroring: StoreMirroring) -> [NSPersistentStoreDescription] {
        [StoreScope.privateStore, StoreScope.sharedStore].map { scope in
            let description = NSPersistentStoreDescription(url: directory.appendingPathComponent(scope.fileName))
            description.shouldAddStoreAsynchronously = false
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            if mirroring == .cloudKit {
                let options = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: CorbieIdentifiers.cloudKitContainer
                )
                options.databaseScope = scope == .privateStore ? .private : .shared
                description.cloudKitContainerOptions = options
            }
            return description
        }
    }

    private static let oneStoreLoadAtATime = NSLock()

    private static func load(_ container: NSPersistentContainer) -> (any Error)? {
        var failure: (any Error)?
        oneStoreLoadAtATime.withLock {
            container.loadPersistentStores { _, error in
                if let error {
                    failure = error
                    log.error("store load failed: \(error.localizedDescription, privacy: .public)")
                }
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
