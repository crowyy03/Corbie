import XCTest
@testable import Corbie

final class RouterTests: XCTestCase {
    func testSchemeTabRoutes() throws {
        XCTAssertEqual(try route("corbie://tasks"), .tasks)
        XCTAssertEqual(try route("corbie://calendar"), .calendar)
        XCTAssertEqual(try route("corbie://wishes"), .wishes)
        XCTAssertEqual(try route("corbie://goals"), .goals)
        XCTAssertEqual(try route("corbie://capsules"), .capsules)
        XCTAssertEqual(try route("corbie://votes"), .votes)
    }

    func testGoalRouteCarriesIdentifier() throws {
        let identifier = UUID()
        XCTAssertEqual(try route("corbie://goals/\(identifier.uuidString)"), .goal(identifier))
    }

    func testGoalRouteRejectsNonIdentifier() throws {
        XCTAssertNil(try route("corbie://goals/not-a-uuid"))
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
    func testDeepLinkSelectsTab() {
        let state = AppState()
        state.open(.capsules)
        XCTAssertEqual(state.selectedTab, .us)
        XCTAssertEqual(state.route, .capsules)

        state.open(.wishes)
        XCTAssertEqual(state.selectedTab, .wishes)
    }

    private func route(_ string: String) throws -> Route? {
        Router.route(for: try XCTUnwrap(URL(string: string)))
    }
}
