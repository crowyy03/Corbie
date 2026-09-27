import CorbieCore
import XCTest
@testable import Corbie

final class PurchaseIntentTests: XCTestCase {
    @MainActor
    func testAnIntentBeforeThereIsASpaceWaitsAndIsBoughtForTheSpaceOnceItExists() async throws {
        let transport = PurchaseRecordingTransport()
        let environment = makeEnvironment(transport)
        let buyer = RecordingBuyer(outcome: .success(signedTransaction: "signed.intent"))

        await environment.purchaseIntents.receive(buyer.request, in: environment)
        XCTAssertTrue(buyer.tokens.isEmpty)
        XCTAssertEqual(environment.purchaseIntents.waiting?.productId, "app.corbie.yearly")

        let space = try await signIn(environment)
        await environment.purchaseIntents.buyWaiting(in: environment)

        XCTAssertEqual(buyer.tokens, [space.id])
        XCTAssertNil(environment.purchaseIntents.waiting)
        let sync = try XCTUnwrap(transport.requests.first { $0.url.path.hasSuffix("/entitlement/sync") })
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: sync.body ?? Data()) as? [String: String])
        XCTAssertEqual(body, ["spaceId": space.id.uuidString.lowercased(), "signedTransaction": "signed.intent"])
        XCTAssertEqual(environment.toasts.current?.text, PaywallCopy.text("paywall.state.purchased"))
    }

    @MainActor
    func testAnIntentWhileSignedInIsBoughtAtOnceWithThisSpacesToken() async throws {
        let transport = PurchaseRecordingTransport()
        let environment = makeEnvironment(transport)
        let space = try await signIn(environment)
        let buyer = RecordingBuyer(outcome: .success(signedTransaction: "signed.now"))

        await environment.purchaseIntents.receive(buyer.request, in: environment)

        XCTAssertEqual(buyer.tokens, [space.id])
        XCTAssertEqual(transport.requests.filter { $0.url.path.hasSuffix("/entitlement/sync") }.count, 1)
    }

    @MainActor
    func testAPendingOrCancelledIntentSyncsNothing() async throws {
        let transport = PurchaseRecordingTransport()
        let environment = makeEnvironment(transport)
        _ = try await signIn(environment)

        await environment.purchaseIntents.receive(RecordingBuyer(outcome: .pending).request, in: environment)
        XCTAssertEqual(environment.toasts.current?.text, PaywallCopy.text("paywall.state.pending"))

        await environment.purchaseIntents.receive(RecordingBuyer(outcome: .cancelled).request, in: environment)
        XCTAssertFalse(transport.requests.contains { $0.url.path.hasSuffix("/entitlement/sync") })
        XCTAssertNil(environment.purchaseIntents.waiting)
    }

    @MainActor
    func testAFailedIntentIsReportedAndNotRetried() async throws {
        let environment = makeEnvironment(PurchaseRecordingTransport())
        _ = try await signIn(environment)
        let buyer = RecordingBuyer(failure: CorbieError.network("purchase failed"))

        await environment.purchaseIntents.receive(buyer.request, in: environment)
        await environment.purchaseIntents.buyWaiting(in: environment)

        XCTAssertEqual(buyer.tokens.count, 1)
        XCTAssertNil(environment.purchaseIntents.waiting)
        XCTAssertNotNil(environment.toasts.current)
    }

    @MainActor
    private func makeEnvironment(_ transport: PurchaseRecordingTransport) -> AppEnvironment {
        AppEnvironment(
            persistence: PersistenceController.inMemory(),
            secrets: InMemorySecretStore(),
            anonymousIdentity: .inMemory(),
            notificationClient: PreviewNotificationClient(),
            transport: transport
        )
    }

    @MainActor
    private func signIn(_ environment: AppEnvironment) async throws -> SpaceDTO {
        let space = try await environment.repositories.spaces.create(displayCurrency: "USD", creatorMemberId: nil, now: Date())
        _ = try await environment.repositories.members.upsertCurrentMember(
            appleUserId: "000123.payer",
            spaceId: space.id,
            draft: MemberDraft(displayName: "Anna"),
            theme: environment.theme.activeTheme
        )
        try environment.storeAppleCredential(userIdentifier: "000123.payer", identityToken: "apple-token")
        await environment.reloadSession()
        XCTAssertTrue(environment.isSignedIn)
        return space
    }
}

private final class RecordingBuyer: @unchecked Sendable {
    private let lock = NSLock()
    private var received: [UUID] = []
    private let answer: Result<PurchaseOutcome, any Error>

    init(outcome: PurchaseOutcome) {
        answer = .success(outcome)
    }

    init(failure: any Error) {
        answer = .failure(failure)
    }

    var tokens: [UUID] {
        lock.withLock { received }
    }

    var request: PurchaseIntentQueue.Request {
        PurchaseIntentQueue.Request(productId: "app.corbie.yearly") { [self] token in
            lock.withLock { received.append(token) }
            return try answer.get()
        }
    }
}

private final class PurchaseRecordingTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [HTTPRequest] = []

    var requests: [HTTPRequest] {
        lock.withLock { recorded }
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.withLock { recorded.append(request) }
        guard request.url.path.contains("/entitlement") else { throw URLError(.notConnectedToInternet) }
        let body = """
        {"spaceId":"\(UUID().uuidString.lowercased())","status":"active","environment":"Production","reconciled":true}
        """
        return HTTPResponse(status: 200, body: Data(body.utf8))
    }
}
