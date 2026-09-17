import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct CloudKitExportWaitTests {
    private static let eventKey = "test.event"
    private let store = "shared-store"
    private let marker = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func aFinishedExportOfTheStoreEndsTheWait() async {
        let center = NotificationCenter()
        let wait = makeWait(center: center)
        let posting = Task {
            try? await Task.sleep(for: .milliseconds(20))
            post(event(.exporting, startedAt: marker.addingTimeInterval(1)), on: center)
        }
        #expect(await wait.outcome(within: .seconds(5)) == .exported)
        await posting.value
    }

    @Test func anExportThatFinishedBeforeTheWaitStillCounts() async {
        let center = NotificationCenter()
        let wait = makeWait(center: center)
        post(event(.exporting, startedAt: marker), on: center)
        #expect(await wait.outcome(within: .seconds(5)) == .exported)
    }

    @Test func aFailedExportIsReportedWithItsReason() async {
        let center = NotificationCenter()
        let wait = makeWait(center: center)
        post(event(.exporting, startedAt: marker.addingTimeInterval(1), succeeded: false, failure: "offline"), on: center)
        #expect(await wait.outcome(within: .seconds(5)) == .failed("offline"))
    }

    @Test func otherEventsDoNotEndTheWait() async {
        let center = NotificationCenter()
        let wait = makeWait(center: center)
        let later = marker.addingTimeInterval(1)
        post(event(.importing, startedAt: later), on: center)
        post(event(.setup, startedAt: later), on: center)
        post(event(.exporting, startedAt: later, endedAt: nil), on: center)
        post(event(.exporting, startedAt: marker.addingTimeInterval(-1)), on: center)
        post(event(.exporting, store: "private-store", startedAt: later), on: center)
        center.post(name: NSPersistentCloudKitContainer.eventChangedNotification, object: nil)
        #expect(await wait.outcome(within: .milliseconds(100)) == .timedOut)
    }

    @Test func theFirstOutcomeWins() async {
        let center = NotificationCenter()
        let wait = makeWait(center: center)
        #expect(await wait.outcome(within: .milliseconds(10)) == .timedOut)
        post(event(.exporting, startedAt: marker), on: center)
        #expect(await wait.outcome(within: .seconds(5)) == .timedOut)
    }

    private func makeWait(center: NotificationCenter) -> CloudKitExportWait {
        CloudKitExportWait(
            storeIdentifier: store,
            startedAtOrAfter: marker,
            center: center,
            readEvent: { notification in
                notification.userInfo?[CloudKitExportWaitTests.eventKey] as? CloudKitMirroringEvent
            }
        )
    }

    private func event(
        _ kind: CloudKitMirroringEvent.Kind,
        store: String? = nil,
        startedAt: Date,
        endedAt: Date? = Date(timeIntervalSince1970: 1_800_000_100),
        succeeded: Bool = true,
        failure: String? = nil
    ) -> CloudKitMirroringEvent {
        CloudKitMirroringEvent(
            kind: kind,
            storeIdentifier: store ?? self.store,
            startedAt: startedAt,
            endedAt: endedAt,
            succeeded: succeeded,
            failure: failure
        )
    }

    private func post(_ event: CloudKitMirroringEvent, on center: NotificationCenter) {
        center.post(
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            userInfo: [CloudKitExportWaitTests.eventKey: event]
        )
    }
}
