import CloudKit
import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct CloudKitActivityLogTests {
    private static let privateZone = "com.apple.coredata.cloudkit.share.A"
    private static let sharedZone = "com.apple.coredata.cloudkit.share.B"
    private static let importAuthor = "NSCloudKitMirroringDelegate.import"

    @Test func anExportLogsLocalWritesByZoneAndEntityAndAnImportLogsOnlyTheMirroringImport() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        bench.log.start()
        let kept = try bench.insert(Wish.entityName, count: 2, author: TransactionAuthor.app.rawValue)
        try bench.update(kept[0], author: TransactionAuthor.share.rawValue)
        let dropped = try bench.insert(TaskItem.entityName, author: TransactionAuthor.app.rawValue)
        try bench.delete(dropped, author: TransactionAuthor.app.rawValue)
        try bench.insert(Person.entityName, author: Self.importAuthor)
        try bench.insert(Person.entityName, author: "NSCloudKitMirroringDelegate.reset")

        bench.log.record(bench.event(.exporting))

        #expect(bench.lines == [
            "export ok store=private zone=\(Self.privateZone) Wish +2 ~1 -0",
            "export ok store=private zone=unknown TaskItem +1 ~0 -1"
        ])

        bench.clearLines()
        bench.log.record(bench.event(.importing))
        #expect(bench.lines == ["import ok store=private zone=\(Self.privateZone) Person +1 ~0 -0"])
    }

    @Test func aChildAddedToItsParentDoesNotCountAsAnUpdateOfTheParent() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        bench.log.start()
        let space = try bench.insert(Space.entityName, author: TransactionAuthor.app.rawValue)
        try bench.insertWish(into: space, author: TransactionAuthor.app.rawValue)
        try bench.update(space, author: TransactionAuthor.app.rawValue)

        bench.log.record(bench.event(.exporting))

        #expect(bench.lines == [
            "export ok store=private zone=\(Self.privateZone) Space +1 ~1 -0",
            "export ok store=private zone=\(Self.privateZone) Wish +1 ~0 -0"
        ])
    }

    @Test func nothingIsLoggedTwiceAndEachStoreKeepsItsOwnMark() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        bench.log.start()
        try bench.insert(Wish.entityName, author: TransactionAuthor.app.rawValue)
        bench.log.record(bench.event(.exporting))
        bench.log.record(bench.event(.exporting))
        #expect(bench.lines == [
            "export ok store=private zone=\(Self.privateZone) Wish +1 ~0 -0",
            "export ok store=private no model changes"
        ])

        bench.clearLines()
        try bench.insert(Wish.entityName, author: TransactionAuthor.app.rawValue, scope: .sharedStore)
        bench.log.record(bench.event(.exporting))
        bench.log.record(bench.event(.exporting, scope: .sharedStore))
        #expect(bench.lines == [
            "export ok store=private no model changes",
            "export ok store=shared zone=\(Self.sharedZone) Wish +1 ~0 -0"
        ])
        #expect(bench.defaults.data(forKey: CloudKitActivityLog.tokenKey(.exporting, .privateStore)) != nil)
        #expect(bench.defaults.data(forKey: CloudKitActivityLog.tokenKey(.exporting, .sharedStore)) != nil)
    }

    @Test func aChangeSavedAfterTheExportStartedWaitsForTheNextExport() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        bench.log.start()
        try bench.insert(Wish.entityName, author: TransactionAuthor.app.rawValue)
        let started = Date()
        try bench.insert(TaskItem.entityName, author: TransactionAuthor.app.rawValue)

        bench.log.record(bench.event(.exporting, startedAt: started))
        bench.log.record(bench.event(.exporting))

        #expect(bench.lines == [
            "export ok store=private zone=\(Self.privateZone) Wish +1 ~0 -0",
            "export ok store=private zone=\(Self.privateZone) TaskItem +1 ~0 -0"
        ])
    }

    @Test func aFailedExportLogsTheErrorAndKeepsItsChangesForTheNextOne() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        bench.log.start()
        try bench.insert(Wish.entityName, author: TransactionAuthor.app.rawValue)
        var failed = bench.event(.exporting, succeeded: false)
        failed.errorReport = CloudKitErrorReport(domain: CKErrorDomain, code: CKError.Code.networkFailure.rawValue)

        bench.log.record(failed)
        bench.log.record(bench.event(.exporting))

        #expect(bench.entries.first == .error("export failed store=private domain=CKErrorDomain code=4"))
        #expect(bench.lines.last == "export ok store=private zone=\(Self.privateZone) Wish +1 ~0 -0")
    }

    @Test func historyWrittenBeforeTheFirstStartIsNotLogged() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        try bench.insert(Wish.entityName, author: TransactionAuthor.app.rawValue)

        bench.log.start()
        bench.log.record(bench.event(.exporting))

        #expect(bench.lines == ["export ok store=private no model changes"])
    }

    @Test func purgedHistoryNeitherCrashesNorBringsBackWhatWasLogged() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        bench.log.start()
        try bench.insert(Wish.entityName, author: TransactionAuthor.app.rawValue)
        bench.log.record(bench.event(.exporting))
        try bench.insert(TaskItem.entityName, author: TransactionAuthor.app.rawValue)
        try bench.purgeHistory()
        try bench.insert(Person.entityName, author: TransactionAuthor.app.rawValue)
        bench.clearLines()

        bench.log.record(bench.event(.exporting))
        bench.log.record(bench.event(.exporting))

        #expect(bench.lines == [
            "export history restarted store=private reason=expired",
            "export ok store=private no model changes"
        ])
    }

    @Test func setupLogsTheKnownZonesOncePerStore() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        bench.log.start()
        try bench.insert(Space.entityName, author: TransactionAuthor.app.rawValue)

        bench.log.record(bench.event(.setup))
        bench.log.record(bench.event(.setup))
        bench.log.record(bench.event(.setup, scope: .sharedStore))

        #expect(bench.lines == [
            "setup ok store=private",
            "zones store=private spaces=\(Self.privateZone) shares=\(Self.privateZone)",
            "setup ok store=private",
            "setup ok store=shared",
            "zones store=shared spaces=none shares=\(Self.sharedZone)"
        ])
    }

    @Test func eventsHeardBeforeStartAreLoggedOnceItStarts() async throws {
        let bench = try Bench(postsSetup: true)
        defer { bench.tearDown() }
        bench.center.post(name: NSPersistentCloudKitContainer.eventChangedNotification, object: nil)
        #expect(bench.lines.isEmpty)

        bench.log.start()

        for _ in 0..<100 where bench.lines.count < 2 {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(bench.lines == ["setup ok store=private", "zones store=private spaces=none shares=\(Self.privateZone)"])
    }

    @Test func aPartialFailureNamesEachRecordUpToTheCap() {
        let zone = CKRecordZone.ID(zoneName: Self.sharedZone, ownerName: "_owner")
        var partials: [AnyHashable: any Error] = [:]
        for index in 0..<25 {
            let record = CKRecord.ID(recordName: String(format: "R%02d", index), zoneID: zone)
            partials[record] = CKError(.serverRecordChanged)
        }
        partials[zone] = CKError(.zoneNotFound)
        let error = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: partials])

        let lines = SyncLog.failureLines("export", store: "shared", report: CloudKitErrorReport(error))

        #expect(lines.count == 22)
        #expect(lines.allSatisfy { $0.level == .error })
        #expect(lines[0].text == "export failed store=shared domain=CKErrorDomain code=2")
        #expect(lines[1].text == "export failed store=shared record=unknown zone=\(Self.sharedZone) code=26")
        #expect(lines[2].text == "export failed store=shared record=R00 zone=\(Self.sharedZone) code=14")
        #expect(lines.last?.text == "export failed store=shared dropped 6 more record errors")
    }

    @Test func anUnderlyingErrorIsNamedWithTheTopOne() {
        let underlying = NSError(domain: CKErrorDomain, code: CKError.Code.notAuthenticated.rawValue)
        let error = NSError(domain: NSCocoaErrorDomain, code: 134_400, userInfo: [NSUnderlyingErrorKey: underlying])

        let lines = SyncLog.failureLines("setup", store: "private", report: CloudKitErrorReport(error))

        #expect(lines.map(\.text) == ["setup failed store=private domain=NSCocoaErrorDomain code=134400 underlying=CKErrorDomain/9"])
    }

    @Test func onlyTheMirroringImportCountsAsAnImport() {
        #expect(SyncDirection.importing.carries(author: "NSCloudKitMirroringDelegate.import"))
        #expect(SyncDirection.importing.carries(author: TransactionAuthor.app.rawValue) == false)
        #expect(SyncDirection.importing.carries(author: nil) == false)
        for author in [TransactionAuthor.app.rawValue, TransactionAuthor.share.rawValue, TransactionAuthor.widgets.rawValue] {
            #expect(SyncDirection.exporting.carries(author: author))
        }
        #expect(SyncDirection.exporting.carries(author: nil))
        for author in ["NSCloudKitMirroringDelegate.import", "NSCloudKitMirroringDelegate.reset", "NSCloudKitMirroringDelegate.export"] {
            #expect(SyncDirection.exporting.carries(author: author) == false)
        }
    }

    @Test func aPurgeNamesTheZoneTheStoreAndWhoAsked() {
        let zone = "com.apple.coredata.cloudkit.share.C"
        #expect(SyncLog.purgeAskedLine(store: "shared", zone: zone, reason: .leave).text
            == "purge asked store=shared zone=\(zone) reason=leave")
        #expect(SyncLog.purgeResultLine(store: "shared", zone: zone, reason: .leave, error: nil, zoneWasMissing: false)
            == .notice("purge ok store=shared zone=\(zone) reason=leave"))
        #expect(SyncLog.purgeResultLine(
            store: "private",
            zone: zone,
            reason: .deleteAccount,
            error: CKError(.zoneNotFound),
            zoneWasMissing: true
        ) == .notice("purge missing store=private zone=\(zone) reason=deleteAccount domain=CKErrorDomain code=26"))
        #expect(SyncLog.purgeResultLine(
            store: "private",
            zone: zone,
            reason: .deleteAccount,
            error: CKError(.networkFailure),
            zoneWasMissing: false
        ) == .error("purge failed store=private zone=\(zone) reason=deleteAccount domain=CKErrorDomain code=4"))
    }

    @Test func aStoreResetForgetsTheSyncLogMarks() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        bench.log.start()
        try bench.insert(Wish.entityName, author: TransactionAuthor.app.rawValue)
        bench.log.record(bench.event(.exporting))
        #expect(bench.defaults.data(forKey: CloudKitActivityLog.tokenKey(.exporting, .privateStore)) != nil)

        StoreReset(stack: bench.stack, defaults: bench.defaults).clearHistoryTokens()

        #expect(CloudKitActivityLog.tokenKeys.allSatisfy { bench.defaults.data(forKey: $0) == nil })
    }
}

private final class EntrySink: @unchecked Sendable {
    private let lock = NSLock()
    private var written: [SyncLogEntry] = []

    var entries: [SyncLogEntry] { lock.withLock { written } }

    func append(_ entry: SyncLogEntry) {
        lock.withLock { written.append(entry) }
    }

    func clear() {
        lock.withLock { written = [] }
    }
}

private final class Bench: @unchecked Sendable {
    let directory: URL
    let suiteName: String
    let defaults: UserDefaults
    let stack: CoreDataStack
    let center = NotificationCenter()
    let log: CloudKitActivityLog
    private let sink = EntrySink()

    init(postsSetup: Bool = false) throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-sync-log-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suiteName = "corbie-sync-log-" + UUID().uuidString
        defaults = try #require(UserDefaults(suiteName: suiteName))
        stack = CoreDataStack(storesIn: directory, author: .app)
        let setup = postsSetup ? Bench.event(.setup, in: stack) : nil
        let container = stack.container
        let sink = sink
        log = CloudKitActivityLog(
            container: container,
            defaults: defaults,
            center: center,
            readEvent: { _ in setup },
            recordZones: { ids in Bench.zones(of: ids, in: container) },
            shareZones: { store in [Bench.zone(of: store)] },
            write: { sink.append($0) }
        )
    }

    var entries: [SyncLogEntry] { sink.entries }
    var lines: [String] { entries.map(\.text) }

    func clearLines() {
        sink.clear()
    }

    func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }

    func event(
        _ kind: CloudKitMirroringEvent.Kind,
        scope: StoreScope = .privateStore,
        startedAt: Date = Date(),
        succeeded: Bool = true
    ) -> CloudKitMirroringEvent {
        Bench.event(kind, in: stack, scope: scope, startedAt: startedAt, succeeded: succeeded)
    }

    static func event(
        _ kind: CloudKitMirroringEvent.Kind,
        in stack: CoreDataStack,
        scope: StoreScope = .privateStore,
        startedAt: Date = Date(),
        succeeded: Bool = true
    ) -> CloudKitMirroringEvent {
        CloudKitMirroringEvent(
            kind: kind,
            storeIdentifier: stack.store(for: scope)?.identifier ?? "",
            startedAt: startedAt,
            endedAt: startedAt,
            succeeded: succeeded
        )
    }

    @discardableResult
    func insert(_ entityName: String, author: String, scope: StoreScope = .privateStore) throws -> NSManagedObjectID {
        try insert(entityName, count: 1, author: author, scope: scope)[0]
    }

    @discardableResult
    func insert(
        _ entityName: String,
        count: Int,
        author: String,
        scope: StoreScope = .privateStore
    ) throws -> [NSManagedObjectID] {
        let store = stack.store(for: scope)
        return try write(author: author) { context in
            let objects = (0..<count).map { _ in NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) }
            if let store {
                objects.forEach { context.assign($0, to: store) }
            }
            try context.obtainPermanentIDs(for: objects)
            return objects.map(\.objectID)
        }
    }

    func insertWish(into spaceID: NSManagedObjectID, author: String) throws {
        try write(author: author) { context in
            guard let space = try context.existingObject(with: spaceID) as? Space else { return }
            let wish = Wish(context: context)
            context.assign(wish, toStoreOf: space)
            wish.space = space
        }
    }

    func update(_ objectID: NSManagedObjectID, author: String) throws {
        try write(author: author) { context in
            context.object(with: objectID).setValue(Date(), forKey: "createdAt")
        }
    }

    func delete(_ objectID: NSManagedObjectID, author: String) throws {
        try write(author: author) { context in
            context.delete(context.object(with: objectID))
        }
    }

    func purgeHistory() throws {
        let context = stack.newBackgroundContext()
        try context.performAndWait {
            _ = try context.execute(NSPersistentHistoryChangeRequest.deleteHistory(before: Date()))
        }
    }

    private func write<T>(author: String, _ body: (NSManagedObjectContext) throws -> T) throws -> T {
        let context = stack.newBackgroundContext()
        context.transactionAuthor = author
        return try context.performAndWait {
            let result = try body(context)
            try context.save()
            return result
        }
    }

    private static func zones(of ids: [NSManagedObjectID], in container: NSPersistentContainer) -> [NSManagedObjectID: String] {
        let context = container.newBackgroundContext()
        return context.performAndWait {
            var zones: [NSManagedObjectID: String] = [:]
            for id in ids {
                guard let object = try? context.existingObject(with: id), let store = object.objectID.persistentStore else {
                    continue
                }
                zones[id] = zone(of: store)
            }
            return zones
        }
    }

    private static func zone(of store: NSPersistentStore) -> String {
        store.url?.lastPathComponent == StoreScope.sharedStore.fileName
            ? "com.apple.coredata.cloudkit.share.B"
            : "com.apple.coredata.cloudkit.share.A"
    }
}
