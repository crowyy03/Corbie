import CorbieCore
import UIKit
import XCTest
@testable import Corbie

@MainActor
final class WishLinkFillTests: XCTestCase {
    private let pasted = "https://www.ikea.com/us/en/p/billy-bookcase-white-00263850/"
    private let canonical = "https://www.ikea.com/us/en/p/billy-bookcase-white-00263850"
    private let imageLink = "https://www.ikea.com/global/assets/range-categorisation/images/billy-bookcases-58288.jpeg"

    private var ikeaResponse: String {
        """
        {"price":null,"title":"BILLY bookcases","author":"IKEA","source":"ikea","currency":null,
        "imageURL":"\(imageLink)","canonicalURL":"\(canonical)"}
        """
    }

    private var emptyResponse: String {
        """
        {"price":129,"title":null,"author":null,"source":"ikea","currency":"USD",
        "imageURL":null,"canonicalURL":"\(canonical)"}
        """
    }

    func testAnIkeaLinkWithoutAPriceStillFillsTheTitleAndThePhoto() async throws {
        let transport = StubTransport(parseResponse: ikeaResponse, imageLink: imageLink, image: pngData())
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: pasted))
        let startingCurrency = model.currency

        try await waitUntil("the parse finishes") { model.parseState != .parsing && model.title.isEmpty == false }

        XCTAssertEqual(model.title, "BILLY bookcases")
        XCTAssertEqual(model.imageURL, imageLink)
        XCTAssertNotNil(model.localImage, "the downloaded photo never reached the form")
        XCTAssertEqual(model.parseState, .idle)
        XCTAssertEqual(model.link, canonical)
        XCTAssertTrue(model.priceText.isEmpty, "a null price must leave the price field alone")
        XCTAssertEqual(model.currency, startingCurrency, "a null currency must leave the picker alone")
        XCTAssertNil(environment.toasts.current, "a link that parsed must not report an error")
        XCTAssertEqual(transport.parseRequests, [pasted])
        XCTAssertEqual(transport.imageRequests, 1)
    }

    func testAPriceInRublesFillsTheTitleAndThePhotoButNotThePrice() async throws {
        let rubles = """
        {"price":7990,"title":"BILLY bookcase","author":null,"source":"ikea","currency":"RUB",
        "imageURL":"\(imageLink)","canonicalURL":"\(canonical)"}
        """
        let transport = StubTransport(parseResponse: rubles, imageLink: imageLink, image: pngData())
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: pasted))
        let startingCurrency = model.currency

        try await waitUntil("the parse finishes") { model.parseState != .parsing && model.title.isEmpty == false }

        XCTAssertEqual(model.title, "BILLY bookcase")
        XCTAssertEqual(model.imageURL, imageLink)
        XCTAssertNotNil(model.localImage)
        XCTAssertEqual(model.parseState, .idle)
        XCTAssertTrue(model.priceText.isEmpty, "a price in a currency the app does not offer must not be filled")
        XCTAssertEqual(model.currency, startingCurrency)
        XCTAssertEqual(model.currencies, SupportedCurrencies.codes)
        XCTAssertNil(environment.toasts.current)
    }

    func testAServerThatRefusesTheLinkTellsThePerson() async throws {
        let transport = StubTransport(parseResponse: nil, imageLink: imageLink, image: Data())
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: pasted))

        try await waitUntil("the parse fails") { model.parseState == .failed }

        XCTAssertTrue(model.title.isEmpty)
        XCTAssertNotNil(environment.toasts.current, "a failed parse must say so, not only change the hint")
    }

    func testALinkThatReadsEmptyIsAFailureAndFillsNothing() async throws {
        let transport = StubTransport(parseResponse: emptyResponse, imageLink: imageLink, image: pngData())
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: pasted))
        let startingCurrency = model.currency

        try await waitUntil("the empty read fails") { model.parseState == .failed }

        XCTAssertTrue(model.title.isEmpty)
        XCTAssertNil(model.imageURL)
        XCTAssertNil(model.localImage)
        XCTAssertTrue(model.priceText.isEmpty, "an empty read must not fill the price either")
        XCTAssertEqual(model.currency, startingCurrency)
        XCTAssertEqual(model.link, pasted, "an empty read must not rewrite the link")
        XCTAssertEqual(environment.toasts.current?.text, String(localized: "wishes.editor.link.empty"))
        XCTAssertEqual(transport.parseRequests, [pasted])
        XCTAssertEqual(transport.imageRequests, 0)
    }

    private func waitUntil(
        _ what: String,
        timeout: TimeInterval = 8,
        _ condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("timed out waiting for \(what)")
    }

    private func pngData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let image = renderer.image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        return image.pngData() ?? Data()
    }
}

private final class StubTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private let parseResponse: String?
    private let imageLink: String
    private let image: Data
    private var recordedParseBodies: [String] = []
    private var recordedImageRequests = 0

    init(parseResponse: String?, imageLink: String, image: Data) {
        self.parseResponse = parseResponse
        self.imageLink = imageLink
        self.image = image
    }

    var parseRequests: [String] {
        lock.withLock { recordedParseBodies }
    }

    var imageRequests: Int {
        lock.withLock { recordedImageRequests }
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        if request.url.absoluteString == imageLink {
            lock.withLock { recordedImageRequests += 1 }
            return HTTPResponse(status: 200, headers: ["content-type": "image/png"], body: image)
        }
        guard request.url.lastPathComponent == "parse" else {
            return HTTPResponse(status: 404, body: Data(#"{"error":"not_found","message":"no stub"}"#.utf8))
        }
        let body = request.body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] }
        lock.withLock { recordedParseBodies.append(body?["url"] ?? "") }
        guard let parseResponse else {
            return HTTPResponse(status: 400, body: Data(#"{"error":"invalid_request","message":"no"}"#.utf8))
        }
        return HTTPResponse(
            status: 200,
            headers: ["content-type": "application/json"],
            body: Data(parseResponse.utf8)
        )
    }
}
