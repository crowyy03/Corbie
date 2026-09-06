import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainReviewPromptTests {
    private func makeTracker() -> ReviewPromptTracker {
        let suite = "review-prompt-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return ReviewPromptTracker(defaults: defaults)
    }

    private let calendar = Calendar(identifier: .gregorian)
    private let install = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func theInstallDateIsRecordedOnce() {
        let tracker = makeTracker()
        tracker.recordLaunch(now: install)
        tracker.recordLaunch(now: install.addingTimeInterval(86_400))
        #expect(tracker.installedAt == install)
    }

    @Test func threeJointActionsAfterFiveDaysAskOnce() {
        let tracker = makeTracker()
        tracker.recordLaunch(now: install)
        for _ in 0..<3 { tracker.recordJointAction() }
        let dayFour = install.addingTimeInterval(4 * 86_400)
        let dayFive = install.addingTimeInterval(5 * 86_400)
        #expect(tracker.shouldRequest(now: dayFour, calendar: calendar) == false)
        #expect(tracker.shouldRequest(now: dayFive, calendar: calendar))
        tracker.markRequested(now: dayFive)
        #expect(tracker.shouldRequest(now: dayFive.addingTimeInterval(86_400), calendar: calendar) == false)
    }

    @Test func twoJointActionsAreNotEnoughHoweverOldTheInstall() {
        let tracker = makeTracker()
        tracker.recordLaunch(now: install)
        tracker.recordJointAction()
        tracker.recordJointAction()
        #expect(tracker.shouldRequest(now: install.addingTimeInterval(30 * 86_400), calendar: calendar) == false)
    }

    @Test func nothingIsAskedBeforeTheFirstLaunchIsRecorded() {
        let tracker = makeTracker()
        for _ in 0..<5 { tracker.recordJointAction() }
        #expect(tracker.shouldRequest(now: install.addingTimeInterval(30 * 86_400), calendar: calendar) == false)
    }
}
