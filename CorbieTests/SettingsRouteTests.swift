import CorbieCore
import UserNotifications
import XCTest
@testable import Corbie

final class SettingsRouteTests: XCTestCase {
    func testTaskAndPeopleLinksCarryIdentifiers() throws {
        let task = UUID()
        XCTAssertEqual(try route("corbie://tasks/\(task.uuidString)"), .task(task))
        XCTAssertEqual(try route("corbie://tasks"), .tasks)
        let person = UUID()
        XCTAssertEqual(try route("corbie://people/\(person.uuidString)"), .person(person))
        XCTAssertEqual(try route("corbie://people"), .people)
    }

    func testALinkWithABrokenIdentifierFallsBackToTheList() throws {
        XCTAssertEqual(try route("corbie://tasks/not-a-uuid"), .tasks)
        XCTAssertEqual(try route("corbie://people/not-a-uuid"), .people)
    }

    func testCoreRoutesMapOntoAppRoutes() {
        let identifier = UUID()
        XCTAssertEqual(Router.route(for: CorbieRoute.task(identifier)), .task(identifier))
        XCTAssertEqual(Router.route(for: CorbieRoute.person(identifier)), .person(identifier))
        XCTAssertEqual(Router.route(for: CorbieRoute.goal(identifier)), .goal(identifier))
        XCTAssertEqual(Router.route(for: CorbieRoute.capsule(identifier)), .capsules)
        XCTAssertEqual(Router.route(for: CorbieRoute.vote(identifier)), .votes)
        XCTAssertEqual(Router.route(for: CorbieRoute.event(identifier)), .calendar)
        XCTAssertEqual(Router.route(for: CorbieRoute.wish(identifier)), .wishes)
        XCTAssertEqual(Router.route(for: CorbieRoute.us), .us)
        XCTAssertNil(Router.route(for: CorbieRoute.paywall))
    }

    func testANotificationWithoutAScreenOfItsOwnOpensToday() {
        let bare = NotificationResponse(actionIdentifier: UNNotificationDefaultActionIdentifier, userInfo: [:])
        XCTAssertEqual(NotificationRouting.outcome(for: bare), .open(.today))
        let paywall = NotificationResponse(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            route: .paywall
        )
        XCTAssertEqual(NotificationRouting.outcome(for: paywall), .open(.today))
    }

    func testEveryCoreRouteStringSurvivesTheRoundTrip() throws {
        let identifier = UUID()
        let routes: [CorbieRoute] = [
            .tasks, .task(identifier), .calendar, .wishes, .goals, .goal(identifier),
            .capsules, .capsule(identifier), .votes, .vote(identifier), .people, .person(identifier), .us
        ]
        for route in routes {
            let parsed = try XCTUnwrap(CorbieRoute(urlString: route.urlString), route.urlString)
            XCTAssertEqual(Router.route(for: parsed), Router.route(for: route), route.urlString)
        }
    }

    @MainActor
    func testANotificationRouteSelectsItsTab() {
        let state = AppState()
        state.open(.task(UUID()))
        XCTAssertEqual(state.selectedTab, .tasks)
        state.open(.person(UUID()))
        XCTAssertTrue(state.isUsHubPresented)
        XCTAssertEqual(state.selectedTab, .tasks)
        state.open(.people)
        XCTAssertTrue(state.isUsHubPresented)
    }

    func testATaskActionRunsTheWriteInsteadOfOpeningAScreen() {
        let identifier = UUID()
        let payload = NotificationPayload.userInfo(kind: .taskDueToday, route: .task(identifier), objectId: identifier)
        let take = NotificationResponse(
            actionIdentifier: NotificationCategories.Action.takeTask,
            userInfo: payload
        )
        XCTAssertEqual(NotificationRouting.outcome(for: take), .takeTask(identifier))
        let done = NotificationResponse(
            actionIdentifier: NotificationCategories.Action.completeTask,
            userInfo: payload
        )
        XCTAssertEqual(NotificationRouting.outcome(for: done), .completeTask(identifier))
    }

    func testATapOpensTheRouteAndADismissDoesNothing() {
        let identifier = UUID()
        let payload = NotificationPayload.userInfo(remote: .voteUpdate, route: .vote(identifier), objectId: identifier)
        let tap = NotificationResponse(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            userInfo: payload
        )
        XCTAssertEqual(NotificationRouting.outcome(for: tap), .open(.votes))
        let castVote = NotificationResponse(
            actionIdentifier: NotificationCategories.Action.castVote,
            userInfo: payload
        )
        XCTAssertEqual(NotificationRouting.outcome(for: castVote), .open(.votes))
        let dismissed = NotificationResponse(
            actionIdentifier: UNNotificationDismissActionIdentifier,
            userInfo: payload
        )
        XCTAssertEqual(NotificationRouting.outcome(for: dismissed), .ignored)
    }

    func testAnActionWithoutATaskIsIgnored() {
        let response = NotificationResponse(
            actionIdentifier: NotificationCategories.Action.takeTask,
            userInfo: [:]
        )
        XCTAssertEqual(NotificationRouting.outcome(for: response), .ignored)
    }

    private func route(_ string: String) throws -> Route? {
        Router.route(for: try XCTUnwrap(URL(string: string)))
    }
}
