import CorbieCore
import UIKit
import XCTest
@testable import Corbie

@MainActor
final class WishLinkFillTests: XCTestCase {
    private let pasted = "https://www.ikea.com/us/en/p/billy-bookcase-white-00263850/"
    private let canonical = "https://www.ikea.com/us/en/p/billy-bookcase-white-00263850"
    private let imageLink = "https://www.ikea.com/global/assets/range-categorisation/images/billy-bookcases-58288.jpeg"
    private let amazonLink = "https://www.amazon.com/dp/B0CRMZHDG8"
    private let amazonTrackedLink = "https://www.amazon.com/dp/B0CRMZHDG8?tag=corbie-20"

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
        XCTAssertEqual(model.priceLeftOut, .unsupportedCurrency("RUB"))
        XCTAssertEqual(
            model.priceHint,
            String(format: String(localized: "wishes.editor.price.hint.unsupported"), "RUB")
        )
        XCTAssertTrue(model.priceHint?.contains("RUB") == true, "the hint must name the shop's currency")
    }

    func testAPriceWithoutAnyCurrencySaysSoUnderThePrice() async throws {
        let transport = stub(amazonResponse(currency: nil))
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: amazonLink))

        try await waitUntil("the parse finishes") { model.parseState != .parsing && model.title.isEmpty == false }

        XCTAssertTrue(model.priceText.isEmpty)
        XCTAssertEqual(model.priceLeftOut, .unknownCurrency)
        XCTAssertEqual(model.priceHint, String(localized: "wishes.editor.price.hint.unknown"))
    }

    func testAKeptPriceLeavesNoHint() async throws {
        let transport = stub(amazonResponse(currency: "USD"))
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: amazonLink))

        try await waitUntil("the parse finishes") { model.parseState != .parsing && model.title.isEmpty == false }

        XCTAssertEqual(model.priceText, WishPricing.text(from: 129))
        XCTAssertEqual(model.currency, "USD")
        XCTAssertNil(model.priceLeftOut)
        XCTAssertNil(model.priceHint)
    }

    func testThePriceHintGoesAwayWhenAPriceIsTypedOrTheLinkChanges() async throws {
        let transport = stub(amazonResponse(currency: nil))
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: amazonLink))
        try await waitUntil("the parse finishes") { model.parseState != .parsing && model.title.isEmpty == false }

        model.linkChanged()
        XCTAssertNotNil(model.priceHint, "the canonical link the read wrote back is not a new link")

        model.priceText = "80"
        XCTAssertNil(model.priceHint)

        model.priceText = ""
        model.link = "https://www.amazon.com/dp/B0DIFFERENT"
        model.linkChanged()
        XCTAssertNil(model.priceLeftOut)
        XCTAssertNil(model.priceHint)
        try await waitUntil("the new link is read") { transport.parseRequests.count == 2 && model.parseState == .idle }
    }

    func testThePriceHintGoesAwayWhenTheFieldStopsBeingALink() async throws {
        let transport = stub(amazonResponse(currency: nil))
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: amazonLink))
        try await waitUntil("the parse finishes") { model.priceHint != nil }

        model.link = "Stanley Quencher"
        model.linkChanged()

        XCTAssertNil(model.priceLeftOut)
        XCTAssertNil(model.priceHint)
    }

    func testAFailedReadIsReadAgainWhenTheSameLinkIsPasted() async throws {
        let transport = stub(nil, ikeaResponse)
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: pasted))
        try await waitUntil("the first read fails") { model.parseState == .failed }

        pasteAgain(pasted, into: model)
        try await waitUntil("the second read fills the form") { model.title.isEmpty == false }

        XCTAssertEqual(model.title, "BILLY bookcases")
        XCTAssertEqual(model.parseState, .idle)
        XCTAssertEqual(transport.parseRequests, [pasted, pasted])
    }

    func testAnEmptyReadIsReadAgainWhenTheSameLinkIsPasted() async throws {
        let transport = stub(emptyResponse, ikeaResponse)
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: pasted))
        try await waitUntil("the empty read fails") { model.parseState == .failed }

        pasteAgain(pasted, into: model)
        try await waitUntil("the second read fills the form") { model.title.isEmpty == false }

        XCTAssertEqual(model.title, "BILLY bookcases")
        XCTAssertEqual(transport.parseRequests, [pasted, pasted])
    }

    func testACancelledReadIsReadAgainWhenTheSameLinkIsPasted() async throws {
        let transport = stub(ikeaResponse, parseDelay: 1)
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: pasted))
        try await waitUntil("the first request is out") { transport.parseRequests.count == 1 }

        pasteAgain(pasted, into: model)
        try await waitUntil("the second read fills the form") { model.title.isEmpty == false }

        XCTAssertEqual(model.title, "BILLY bookcases")
        XCTAssertEqual(transport.parseRequests, [pasted, pasted])
        XCTAssertNil(environment.toasts.current, "a read cancelled by the person is not an error")
    }

    func testAReadCancelledWhileItsPhotoDownloadsLeavesTheNewLinkAlone() async throws {
        let other = "https://www.amazon.com/dp/B0DIFFERENT"
        let transport = stub(ikeaResponse, nil, imageDelay: 3)
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: pasted))
        try await waitUntil("the photo download starts") { transport.imageRequests == 1 }

        model.link = other
        model.linkChanged()
        try await waitUntil("the new link is read") { transport.parseRequests.count == 2 && model.parseState == .failed }

        XCTAssertEqual(model.link, other, "the cancelled read wrote its link over the new one")
        XCTAssertTrue(model.title.isEmpty, "the cancelled read filled the form")
        XCTAssertNil(model.imageURL)
        XCTAssertEqual(transport.parseRequests, [pasted, other])
    }

    func testReturnReadsALinkWhoseReadFailed() async throws {
        let transport = stub(nil, ikeaResponse)
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: pasted))
        try await waitUntil("the first read fails") { model.parseState == .failed }

        model.linkSubmitted()
        try await waitUntil("the second read fills the form") { model.title.isEmpty == false }

        XCTAssertEqual(model.title, "BILLY bookcases")
        XCTAssertEqual(transport.parseRequests, [pasted, pasted])
    }

    func testReturnDoesNotReadALinkThatIsBeingReadOrWasRead() async throws {
        let transport = stub(ikeaResponse, parseDelay: 0.5)
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: pasted))
        try await waitUntil("the read is out") { model.parseState == .parsing }

        model.linkSubmitted()
        try await waitUntil("the read fills the form") { model.title.isEmpty == false && model.parseState == .idle }
        model.linkSubmitted()
        try await Task.sleep(for: .milliseconds(800))

        XCTAssertEqual(transport.parseRequests, [pasted])
    }

    func testGoingBackToALinkThatWasReadReadsItAgain() async throws {
        let transport = stub(amazonResponse(currency: nil))
        let environment = try await environmentWithStoredSpace(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: amazonLink))
        try await waitUntil("the first read finishes") { model.priceHint != nil }

        model.link = "https://www.amazon.com/dp/B0DIFFERENT"
        model.linkChanged()
        model.link = amazonLink
        model.linkChanged()
        XCTAssertNil(model.priceHint)
        try await waitUntil("the link is read again") { transport.parseRequests.count == 2 && model.priceHint != nil }

        XCTAssertEqual(transport.parseRequests, [amazonLink, amazonLink])
        let saved = await model.save()
        XCTAssertTrue(saved)
        let spaceId = try XCTUnwrap(environment.space?.id)
        let pending = try await environment.repositories.wishes.pendingParse(spaceId: spaceId)
        XCTAssertTrue(pending.isEmpty, "a link the form was filled from is not waiting for a read")
    }

    func testOpeningAWishDoesNotReadItsSavedLink() async throws {
        let transport = stub(ikeaResponse)
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        for needsParse in [false, true] {
            let model = WishEditorViewModel()
            let wish = WishDTO(id: UUID(), title: "", url: pasted, needsParse: needsParse)
            model.configure(environment, request: WishEditorRequest(wish: wish))
            model.linkChanged()
        }
        try await Task.sleep(for: .milliseconds(800))

        XCTAssertEqual(transport.parseRequests, [], "opening the editor started a read")
    }

    func testTheUnreadSavedLinkOfAWishIsReadWhenPastedAgainOrOnReturn() async throws {
        let transport = stub(ikeaResponse)
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let unread = WishDTO(id: UUID(), title: "", url: pasted, needsParse: true)

        let pasting = WishEditorViewModel()
        pasting.configure(environment, request: WishEditorRequest(wish: unread))
        pasteAgain(pasted, into: pasting)
        try await waitUntil("the pasted link is read") { pasting.title.isEmpty == false }

        let returning = WishEditorViewModel()
        returning.configure(environment, request: WishEditorRequest(wish: unread))
        returning.linkSubmitted()
        try await waitUntil("return reads the link") { returning.title.isEmpty == false }

        XCTAssertEqual(transport.parseRequests, [pasted, pasted])
    }

    func testReturnDoesNotReadASavedLinkThatWasRead() async throws {
        let transport = stub(ikeaResponse)
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: WishDTO(id: UUID(), title: "Lamp", url: pasted)))

        model.linkSubmitted()
        try await Task.sleep(for: .milliseconds(800))

        XCTAssertEqual(transport.parseRequests, [])
    }

    func testSavingAnEditedWishKeepsItsStoredLinkAsItWas() async throws {
        let environment = try await environmentWithStoredSpace(transport: stub(ikeaResponse))
        let spaceId = try XCTUnwrap(environment.space?.id)
        let memberId = try XCTUnwrap(environment.currentMember?.id)
        for stored in ["https://www.example.com/p/lamp.", "https://www.example.com/p/lamp!", "https://www.example.com/p/lamp)"] {
            let wish = try await environment.repositories.wishes.create(
                WishDraft(spaceId: spaceId, ownerMemberId: memberId, addedByMemberId: memberId, title: "Lamp", url: stored)
            )
            let model = WishEditorViewModel()
            model.configure(environment, request: WishEditorRequest(wish: wish))
            model.note = "for the hall"

            let saved = await model.save()
            XCTAssertTrue(saved)
            let reloaded = try await environment.repositories.wishes.wish(id: wish.id)
            XCTAssertEqual(reloaded?.url, stored)
        }
    }

    func testALinkInsideTextIsReadFromTheLinkField() async throws {
        let transport = stub(amazonResponse(currency: "USD"))
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: nil))

        model.link = "Stanley Quencher H2.0 40 oz 4.5 stars https://a.co/d/abc123"
        model.linkChanged()
        XCTAssertTrue(model.canSave)
        try await waitUntil("the parse finishes") { model.parseState != .parsing && model.title.isEmpty == false }

        XCTAssertEqual(transport.parseRequests, ["https://a.co/d/abc123"])
        XCTAssertEqual(model.link, amazonLink)
    }

    func testALinkInsideTextIsSavedAsTheLinkWhenTheReadFails() async throws {
        let environment = try await environmentWithStoredSpace(transport: stub(nil))
        let model = WishEditorViewModel()
        model.configure(environment, request: WishEditorRequest(wish: nil, link: nil))
        model.link = "Check this out https://www.target.com/p/x/-/A-1"
        model.linkChanged()
        try await waitUntil("the read fails") { model.parseState == .failed }

        let saved = await model.save()

        XCTAssertTrue(saved)
        let spaceId = try XCTUnwrap(environment.space?.id)
        let pending = try await environment.repositories.wishes.pendingParse(spaceId: spaceId)
        XCTAssertEqual(pending.map(\.url), ["https://www.target.com/p/x/-/A-1"])
    }

    func testAGiftIdeaKeepsThePersonsOwnPriceAndItsCurrency() async throws {
        let transport = stub(amazonResponse(currency: "USD"))
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = GiftIdeaEditorViewModel(personId: UUID(), mode: .new)
        model.bind(environment)
        model.priceText = "50"
        model.currency = "EUR"
        model.link = amazonLink

        await model.parseLinkIfNeeded()

        XCTAssertEqual(model.title, "Stanley Quencher")
        XCTAssertEqual(model.priceText, "50")
        XCTAssertEqual(model.currency, "EUR", "the shop's currency must not relabel the person's own number")
    }

    func testAGiftIdeaTakesThePriceAndItsCurrencyTogether() async throws {
        let transport = stub(amazonResponse(currency: "GBP"))
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = GiftIdeaEditorViewModel(personId: UUID(), mode: .new)
        model.bind(environment)
        model.currency = "EUR"
        model.link = amazonLink

        await model.parseLinkIfNeeded()

        XCTAssertEqual(GiftIdeaEditorViewModel.price(from: model.priceText), 129)
        XCTAssertEqual(model.currency, "GBP")
    }

    func testAGiftIdeaLinkThatFailedIsReadAgain() async throws {
        let transport = stub(nil, amazonResponse(currency: "USD"))
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = GiftIdeaEditorViewModel(personId: UUID(), mode: .new)
        model.bind(environment)
        model.link = amazonLink

        await model.parseLinkIfNeeded()
        XCTAssertTrue(model.hasFailedLink)
        await model.parseLinkIfNeeded()

        XCTAssertFalse(model.hasFailedLink)
        XCTAssertEqual(model.title, "Stanley Quencher")
        XCTAssertEqual(transport.parseRequests, [amazonLink, amazonLink])
    }

    func testAnEmptyGiftIdeaReadLeavesTheLinkAndIsReadAgain() async throws {
        let emptyAmazon = """
        {"price":null,"title":null,"author":null,"source":"amazon","currency":null,
        "imageURL":null,"canonicalURL":"\(amazonLink)"}
        """
        let transport = stub(emptyAmazon, amazonResponse(currency: "USD"))
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = GiftIdeaEditorViewModel(personId: UUID(), mode: .new)
        model.bind(environment)
        model.link = amazonTrackedLink

        await model.parseLinkIfNeeded()
        XCTAssertTrue(model.hasFailedLink)
        XCTAssertEqual(model.link, amazonTrackedLink)
        await model.parseLinkIfNeeded()

        XCTAssertEqual(model.title, "Stanley Quencher")
        XCTAssertEqual(model.link, amazonLink)
        XCTAssertEqual(transport.parseRequests, [amazonTrackedLink, amazonTrackedLink])
    }

    func testAGiftIdeaLinkIsReadOnceWhenReturnAndLeavingTheFieldBothAsk() async throws {
        let transport = stub(amazonResponse(currency: "USD"), parseDelay: 0.3)
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = GiftIdeaEditorViewModel(personId: UUID(), mode: .new)
        model.bind(environment)
        model.link = amazonLink

        async let submitted: Void = model.parseLinkIfNeeded()
        async let leftTheField: Void = model.parseLinkIfNeeded()
        _ = await (submitted, leftTheField)

        XCTAssertEqual(transport.parseRequests, [amazonLink])
        XCTAssertEqual(model.title, "Stanley Quencher")
        XCTAssertFalse(model.isParsing)
    }

    func testAGiftIdeaReadOfAnEarlierLinkDoesNotOverwriteTheNewOne() async throws {
        let transport = stub(amazonResponse(currency: "USD"), ikeaResponse, parseDelay: 0.5)
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = GiftIdeaEditorViewModel(personId: UUID(), mode: .new)
        model.bind(environment)
        model.link = amazonLink

        let first = Task { await model.parseLinkIfNeeded() }
        try await waitUntil("the first read is out") { transport.parseRequests.count == 1 }
        try await Task.sleep(for: .milliseconds(200))
        model.link = pasted
        let second = Task { await model.parseLinkIfNeeded() }
        await first.value
        XCTAssertTrue(model.isParsing, "the earlier read ended the loading state of the newer one")
        await second.value

        XCTAssertEqual(transport.parseRequests, [amazonLink, pasted])
        XCTAssertEqual(model.title, "BILLY bookcases")
        XCTAssertEqual(model.link, canonical)
        XCTAssertFalse(model.hasFailedLink)
    }

    func testAGiftIdeaReadIsDroppedWhenTheLinkChangedMeanwhile() async throws {
        let transport = stub(amazonResponse(currency: "USD"), parseDelay: 0.5)
        let environment = AppEnvironment.previewSignedIn(transport: transport)
        let model = GiftIdeaEditorViewModel(personId: UUID(), mode: .new)
        model.bind(environment)
        model.link = amazonLink

        let read = Task { await model.parseLinkIfNeeded() }
        try await waitUntil("the read is out") { transport.parseRequests.count == 1 }
        model.link = "https://www.amazon.com/dp/B0DI"
        await read.value

        XCTAssertEqual(model.link, "https://www.amazon.com/dp/B0DI")
        XCTAssertTrue(model.title.isEmpty)
        XCTAssertFalse(model.isParsing)
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

    private func amazonResponse(currency: String?) -> String {
        let code = currency.map { "\"\($0)\"" } ?? "null"
        return """
        {"price":129,"title":"Stanley Quencher","author":null,"source":"amazon","currency":\(code),
        "imageURL":"\(imageLink)","canonicalURL":"\(amazonLink)"}
        """
    }

    private func environmentWithStoredSpace(transport: StubTransport) async throws -> AppEnvironment {
        let persistence = PersistenceController.inMemory()
        let repositories = persistence.repositories
        let space = try await repositories.spaces.create(displayCurrency: "USD", creatorMemberId: nil, now: Date())
        let member = try await repositories.members.upsertCurrentMember(
            appleUserId: "tests.me",
            spaceId: space.id,
            draft: MemberDraft(displayName: "Ilya", colorKey: MemberColorSlot.teal.rawValue),
            theme: .sand
        ).member
        return AppEnvironment.previewSignedIn(
            persistence: persistence,
            space: space,
            member: member,
            partner: nil,
            transport: transport
        )
    }

    private func stub(
        _ responses: String?...,
        parseDelay: TimeInterval = 0,
        imageDelay: TimeInterval = 0
    ) -> StubTransport {
        StubTransport(
            parseResponses: responses,
            imageLink: imageLink,
            image: pngData(),
            parseDelay: parseDelay,
            imageDelay: imageDelay
        )
    }

    private func pasteAgain(_ link: String, into model: WishEditorViewModel) {
        model.link = ""
        model.linkChanged()
        model.link = link
        model.linkChanged()
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
    private var parseResponses: [String?]
    private let imageLink: String
    private let image: Data
    private let parseDelay: TimeInterval
    private let imageDelay: TimeInterval
    private var recordedParseBodies: [String] = []
    private var recordedImageRequests = 0

    init(
        parseResponses: [String?],
        imageLink: String,
        image: Data,
        parseDelay: TimeInterval = 0,
        imageDelay: TimeInterval = 0
    ) {
        self.parseResponses = parseResponses
        self.imageLink = imageLink
        self.image = image
        self.parseDelay = parseDelay
        self.imageDelay = imageDelay
    }

    convenience init(parseResponse: String?, imageLink: String, image: Data, parseDelay: TimeInterval = 0) {
        self.init(parseResponses: [parseResponse], imageLink: imageLink, image: image, parseDelay: parseDelay)
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
            if imageDelay > 0 {
                try await Task.sleep(for: .seconds(imageDelay))
            }
            return HTTPResponse(status: 200, headers: ["content-type": "image/png"], body: image)
        }
        guard request.url.lastPathComponent == "parse" else {
            return HTTPResponse(status: 404, body: Data(#"{"error":"not_found","message":"no stub"}"#.utf8))
        }
        let body = request.body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] }
        let parseResponse = lock.withLock {
            recordedParseBodies.append(body?["url"] ?? "")
            return parseResponses.count > 1 ? parseResponses.removeFirst() : parseResponses[0]
        }
        if parseDelay > 0 {
            try await Task.sleep(for: .seconds(parseDelay))
        }
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
