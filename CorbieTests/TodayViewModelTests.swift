import CorbieCore
import XCTest
@testable import Corbie

@MainActor
final class TodayViewModelTests: XCTestCase {
    func testTappingACarouselPlanOpensItInThePlansTab() {
        let analytics = BlockAnalytics()
        let model = makeModel(analytics: analytics)
        let appState = AppState()
        let plan = carouselPlan()

        model.open(.plan(plan.id), block: .plans, in: appState)

        XCTAssertEqual(appState.selectedTab, .plans)
        XCTAssertEqual(appState.route, .plan(plan.id))
        XCTAssertFalse(appState.isUsHubPresented)
        XCTAssertEqual(analytics.names, ["today_block_tapped"])
    }

    func testTappingATaskRowStaysOnTheTasksTab() {
        let model = makeModel(analytics: BlockAnalytics())
        let appState = AppState()
        let taskId = UUID()

        model.open(.task(taskId), block: .tasks, in: appState)

        XCTAssertEqual(appState.selectedTab, .tasks)
        XCTAssertEqual(appState.route, .task(taskId))
    }

    private func makeModel(analytics: BlockAnalytics) -> TodayViewModel {
        TodayViewModel(
            repositories: PersistenceController.inMemory().repositories,
            notifications: NotificationScheduler(client: PreviewNotificationClient()),
            analytics: analytics
        )
    }

    private func carouselPlan() -> TodayPlan {
        TodayPlan(
            id: UUID(),
            title: "Lisbon",
            type: .trip,
            progress: 0.48,
            savedText: "$2,400",
            targetText: "$5,000",
            doneStepCount: 1,
            stepCount: 3
        )
    }
}

private final class BlockAnalytics: AnalyticsRecording, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []

    var names: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func record(_ event: AnalyticsEvent) {
        lock.lock()
        recorded.append(event.name)
        lock.unlock()
    }
}
