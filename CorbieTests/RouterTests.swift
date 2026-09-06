import XCTest
@testable import Corbie

final class RouterTests: XCTestCase {
    func testSchemeTabRoutes() throws {
        XCTAssertEqual(try route("corbie://today"), .today)
        XCTAssertEqual(try route("corbie://tasks"), .tasks)
        XCTAssertEqual(try route("corbie://calendar"), .calendar)
        XCTAssertEqual(try route("corbie://wishes"), .wishes)
        XCTAssertEqual(try route("corbie://plans"), .plans)
        XCTAssertEqual(try route("corbie://capsules"), .capsules)
        XCTAssertEqual(try route("corbie://votes"), .votes)
        XCTAssertEqual(try route("corbie://us"), .us)
    }

    func testTheGoalsAliasAndTheListsLinkBothLandOnPlans() throws {
        let identifier = UUID()
        XCTAssertEqual(try route("corbie://goals"), .plans)
        XCTAssertEqual(try route("corbie://goals/\(identifier.uuidString)"), .plan(identifier))
        XCTAssertEqual(try route("corbie://lists"), .plans)
        XCTAssertEqual(try route("corbie://lists/\(identifier.uuidString)"), .plans)
    }

    func testPlanRouteCarriesIdentifier() throws {
        let identifier = UUID()
        XCTAssertEqual(try route("corbie://plans/\(identifier.uuidString)"), .plan(identifier))
    }

    func testPlanRouteRejectsNonIdentifier() throws {
        XCTAssertNil(try route("corbie://plans/not-a-uuid"))
    }

    func testJoinRoutes() throws {
        XCTAssertEqual(try route("corbie://join/k7m2qx"), .join("K7M2QX"))
        XCTAssertEqual(try route("https://corbie.app/join/K7M2QX"), .join("K7M2QX"))
        XCTAssertEqual(try route("https://www.corbie.app/join/K7M2QX"), .join("K7M2QX"))
    }

    func testUnknownLinksAreIgnored() throws {
        XCTAssertNil(try route("corbie://nowhere"))
        XCTAssertNil(try route("https://example.com/join/K7M2QX"))
        XCTAssertNil(try route("https://corbie.app/pricing"))
    }

    @MainActor
    func testDeepLinkSelectsTabOrOpensTheHub() {
        let state = AppState()
        state.open(.capsules)
        XCTAssertTrue(state.isUsHubPresented)
        XCTAssertEqual(state.selectedTab, .today)
        XCTAssertEqual(state.route, .capsules)

        state.open(.wishes)
        XCTAssertFalse(state.isUsHubPresented)
        XCTAssertEqual(state.selectedTab, .wishes)

        state.open(.us)
        XCTAssertTrue(state.isUsHubPresented)
        XCTAssertEqual(state.selectedTab, .wishes)

        state.open(.today)
        XCTAssertFalse(state.isUsHubPresented)
        XCTAssertEqual(state.selectedTab, .today)
    }

    private func route(_ string: String) throws -> Route? {
        Router.route(for: try XCTUnwrap(URL(string: string)))
    }
}
