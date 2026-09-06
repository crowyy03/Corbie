import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainCorbieRouteTests {
    @Test func routesRoundTripThroughTheDeepLinkString() {
        let id = UUID()
        let routes: [CorbieRoute] = [
            .tasks, .task(id), .calendar, .event(id), .wishes, .wish(id), .plans, .plan(id),
            .capsules, .capsule(id), .votes, .vote(id), .people, .person(id), .us, .paywall
        ]
        for route in routes {
            #expect(route.urlString.hasPrefix("corbie://"))
            #expect(CorbieRoute(urlString: route.urlString) == route)
        }
    }

    @Test func unknownRoutesAreRejected() {
        #expect(CorbieRoute(urlString: "https://corbie.app/tasks") == nil)
        #expect(CorbieRoute(urlString: "corbie://nowhere") == nil)
        #expect(CorbieRoute(urlString: "corbie://") == nil)
        #expect(CorbieRoute(urlString: "corbie://events") == nil)
    }

    @Test func payloadCarriesKindRouteAndObject() {
        let eventId = UUID()
        let info = NotificationPayload.userInfo(kind: .eventDigest, route: .event(eventId), objectId: eventId)
        #expect(NotificationPayload.kind(from: info) == .eventDigest)
        #expect(NotificationPayload.route(from: info) == .event(eventId))
        #expect(NotificationPayload.objectId(from: info) == eventId)
        #expect(NotificationPayload.route(from: [:]) == nil)
    }
}
