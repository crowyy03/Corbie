import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct CloudKitExportLedgerTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    @Test func nothingIsDeletedForAStoreThatNeverUploaded() {
        let cutoff = HistoryCleanupRule.cutoff(
            now: now,
            storeIdentifiers: ["private", "shared"],
            lastUploadStarts: ["private": now]
        )
        #expect(cutoff == nil)
        #expect(HistoryCleanupRule.cutoff(now: now, storeIdentifiers: [], lastUploadStarts: [:]) == nil)
    }

    @Test func theCutoffIsTheEarlierOfAWeekAgoAndTheOldestUpload() {
        let recent = HistoryCleanupRule.cutoff(
            now: now,
            storeIdentifiers: ["private", "shared"],
            lastUploadStarts: ["private": now, "shared": now.addingTimeInterval(-day)]
        )
        #expect(recent == now.addingTimeInterval(-HistoryCleanupRule.retention))

        let stale = now.addingTimeInterval(-10 * day)
        let behind = HistoryCleanupRule.cutoff(
            now: now,
            storeIdentifiers: ["private", "shared"],
            lastUploadStarts: ["private": now, "shared": stale]
        )
        #expect(behind == stale)
    }

    @Test func onlyFinishedSuccessfulUploadsMoveTheLedgerForward() throws {
        let suiteName = "corbie-export-ledger-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let ledger = CloudKitExportLedger(defaults: defaults, center: NotificationCenter())

        ledger.record(event(.exporting, startedAt: now, endedAt: nil, succeeded: false))
        ledger.record(event(.exporting, startedAt: now, endedAt: now, succeeded: false))
        ledger.record(event(.importing, startedAt: now, endedAt: now, succeeded: true))
        #expect(ledger.lastUploadStarts.isEmpty)

        ledger.record(event(.exporting, startedAt: now, endedAt: now.addingTimeInterval(5), succeeded: true))
        ledger.record(event(.exporting, startedAt: now.addingTimeInterval(-60), endedAt: now, succeeded: true))
        #expect(ledger.lastUploadStarts == ["private": now])

        let reopened = CloudKitExportLedger(defaults: defaults, center: NotificationCenter())
        #expect(reopened.lastUploadStarts == ["private": now])
    }

    @Test func theLedgerHearsTheContainerEvents() throws {
        let suiteName = "corbie-export-ledger-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let center = NotificationCenter()
        let upload = event(.exporting, startedAt: now, endedAt: now, succeeded: true)
        let ledger = CloudKitExportLedger(defaults: defaults, center: center, readEvent: { _ in upload })
        center.post(name: NSPersistentCloudKitContainer.eventChangedNotification, object: nil)
        #expect(ledger.lastUploadStarts == ["private": now])
    }

    @Test func aStoreResetForgetsTheUploads() throws {
        let suiteName = "corbie-export-ledger-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let ledger = CloudKitExportLedger(defaults: defaults, center: NotificationCenter())
        ledger.record(event(.exporting, startedAt: now, endedAt: now, succeeded: true))
        StoreReset(stack: CoreDataStack(inMemoryAuthor: .tests), defaults: defaults).clearHistoryTokens()
        #expect(ledger.lastUploadStarts.isEmpty)
    }

    private func event(
        _ kind: CloudKitMirroringEvent.Kind,
        startedAt: Date,
        endedAt: Date?,
        succeeded: Bool
    ) -> CloudKitMirroringEvent {
        CloudKitMirroringEvent(
            kind: kind,
            storeIdentifier: "private",
            startedAt: startedAt,
            endedAt: endedAt,
            succeeded: succeeded
        )
    }
}
