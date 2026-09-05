import CorbieCore
import XCTest
@testable import Corbie

final class WishesLogicTests: XCTestCase {
    private let me = UUID()
    private let partner = UUID()

    func testPartnerChipIsTheDefaultWhenPaired() {
        XCTAssertEqual(WishesFilter.defaultSelection(isPaired: true), .partner)
        XCTAssertEqual(WishesFilter.available(isPaired: true), [.partner, .me, .all])
    }

    func testMeChipIsTheDefaultWhenAlone() {
        XCTAssertEqual(WishesFilter.defaultSelection(isPaired: false), .me)
        XCTAssertEqual(WishesFilter.available(isPaired: false), [.me, .all])
    }

    func testPartnerFilterFallsBackWhenThePartnerLeaves() {
        XCTAssertEqual(WishesFilter.partner.resolved(isPaired: false), .me)
        XCTAssertEqual(WishesFilter.partner.resolved(isPaired: true), .partner)
        XCTAssertEqual(WishesFilter.all.resolved(isPaired: false), .all)
    }

    func testChipCountsSplitByOwner() {
        let owners = WishesOwners(me: me, partner: partner)
        let wishes = [wish(owner: partner), wish(owner: partner), wish(owner: me)]

        XCTAssertEqual(WishesGrouping.count(wishes, matching: .partner, owners: owners), 2)
        XCTAssertEqual(WishesGrouping.count(wishes, matching: .me, owners: owners), 1)
        XCTAssertEqual(WishesGrouping.count(wishes, matching: .all, owners: owners), 3)
    }

    func testPartnerFilterShowsNothingWithoutAPartner() {
        let owners = WishesOwners(me: me, partner: nil)
        XCTAssertTrue(WishesGrouping.wishes([wish(owner: partner)], matching: .partner, owners: owners).isEmpty)
    }

    func testApproximateConvertsIntoTheSpaceCurrency() throws {
        let money = Money(amount: Decimal(48), currency: "USD")
        let rates = FXRates(base: "USD", date: Date(), rates: ["EUR": 0.9], fetchedAt: Date())

        let approximate = try XCTUnwrap(WishPricing.approximate(money, in: "eur", rates: rates))

        XCTAssertEqual(approximate.currency, "EUR")
        XCTAssertEqual(NSDecimalNumber(decimal: approximate.amount).doubleValue, 43.2, accuracy: 0.001)
        let text = approximate.approximate(locale: Locale(identifier: "en_US"))
        XCTAssertTrue(text.hasPrefix("\u{2248} "), text)
        XCTAssertTrue(text.contains("43.20"), text)
    }

    func testApproximateStaysSilentWithoutAUsableRate() {
        let money = Money(amount: Decimal(48), currency: "USD")
        let rates = FXRates(base: "USD", date: Date(), rates: ["EUR": 0.9], fetchedAt: Date())

        XCTAssertNil(WishPricing.approximate(money, in: "USD", rates: rates))
        XCTAssertNil(WishPricing.approximate(money, in: "EUR", rates: nil))
        XCTAssertNil(WishPricing.approximate(money, in: "GBP", rates: rates))
        XCTAssertNil(WishPricing.approximate(Money(amount: Decimal(48), currency: "GBP"), in: "EUR", rates: rates))
    }

    func testMoneyNeedsBothAPriceAndACurrency() {
        XCTAssertNil(WishPricing.money(for: wish(owner: me, price: nil, currency: "USD")))
        XCTAssertNil(WishPricing.money(for: wish(owner: me, price: 10, currency: nil)))
        XCTAssertNil(WishPricing.money(for: wish(owner: me, price: 10, currency: "dollars")))
        XCTAssertEqual(WishPricing.money(for: wish(owner: me, price: 10, currency: "usd"))?.currency, "USD")
    }

    func testRatesAreFetchedOnlyForForeignCurrencies() {
        let wishes = [
            wish(owner: me, price: 10, currency: "USD"),
            wish(owner: me, price: 20, currency: "EUR"),
            wish(owner: me, price: 30, currency: "EUR"),
            wish(owner: me, price: nil, currency: "GBP")
        ]

        XCTAssertEqual(WishPricing.currenciesNeedingRates(wishes, displayCurrency: "USD"), ["EUR"])
    }

    func testPriceTextRoundTripsThroughTheLocale() {
        let german = Locale(identifier: "de_DE")
        XCTAssertEqual(WishPricing.amount(from: "24,99", locale: german), 24.99)
        XCTAssertEqual(WishPricing.amount(from: "24.99", locale: Locale(identifier: "en_US")), 24.99)
        XCTAssertEqual(WishPricing.text(from: 24.99, locale: german), "24,99")
        XCTAssertNil(WishPricing.amount(from: "  ", locale: german))
    }

    func testRetryPicksOnlyPendingLinksWhileOnline() {
        let pending = wish(owner: me, url: "https://www.etsy.com/listing/1", needsParse: true)
        let done = wish(owner: me, url: "https://www.etsy.com/listing/2", needsParse: false)
        let noLink = wish(owner: me, url: nil, needsParse: true)
        let broken = wish(owner: me, url: "not a link", needsParse: true)
        let gifted = wish(owner: me, url: "https://www.etsy.com/listing/3", needsParse: true, isFulfilled: true)
        let all = [pending, done, noLink, broken, gifted]

        XCTAssertEqual(WishParseRetry.candidates(in: all, attempted: [], isOnline: true).map(\.id), [pending.id])
        XCTAssertTrue(WishParseRetry.candidates(in: all, attempted: [], isOnline: false).isEmpty)
        XCTAssertTrue(WishParseRetry.candidates(in: all, attempted: [pending.id], isOnline: true).isEmpty)
    }

    func testRetryStopsAtTheBatchLimit() {
        let wishes = (0 ..< 8).map { index in
            wish(owner: me, url: "https://www.etsy.com/listing/\(index)", needsParse: true)
        }

        XCTAssertEqual(WishParseRetry.candidates(in: wishes, attempted: [], isOnline: true).count, WishParseRetry.batchLimit)
        XCTAssertEqual(WishParseRetry.candidates(in: wishes, attempted: [], isOnline: true, limit: 2).count, 2)
    }

    func testParsedLinkFillsOnlyTheEmptyFields() throws {
        var stored = wish(owner: me, url: "https://etsy.com/listing/1", needsParse: true)
        stored.title = "Linen apron"
        stored.price = nil
        let parsed = ParsedLink(
            canonicalURL: try XCTUnwrap(URL(string: "https://www.etsy.com/listing/1")),
            source: .etsy,
            title: "Apron, sand",
            price: 48,
            currency: "usd",
            imageURL: URL(string: "https://img.example.com/1.jpg"),
            imageData: Data([1, 2, 3])
        )

        let filled = WishParsedFill.merged(parsed, into: stored)

        XCTAssertEqual(filled.title, "Linen apron")
        XCTAssertEqual(filled.price, 48)
        XCTAssertEqual(filled.currency, "USD")
        XCTAssertEqual(filled.source, .etsy)
        XCTAssertEqual(filled.url, "https://www.etsy.com/listing/1")
        XCTAssertEqual(filled.imageURL, "https://img.example.com/1.jpg")
        XCTAssertEqual(filled.localImage, Data([1, 2, 3]))
        XCTAssertFalse(filled.needsParse)
    }

    func testCurrencyOptionsPutTheSpaceCurrencyFirst() {
        let options = WishEditorViewModel.currencyOptions(
            spaceCurrency: "eur",
            supported: ["USD", "EUR", "GBP"],
            wishCurrency: "chf"
        )

        XCTAssertEqual(options, ["EUR", "CHF", "USD", "GBP"])
        XCTAssertEqual(WishEditorViewModel.currencyOptions(spaceCurrency: nil, supported: [], wishCurrency: nil), ["USD"])
    }

    private func wish(
        owner: UUID,
        price: Double? = nil,
        currency: String? = nil,
        url: String? = nil,
        needsParse: Bool = false,
        isFulfilled: Bool = false
    ) -> WishDTO {
        WishDTO(
            id: UUID(),
            ownerMemberId: owner,
            title: "Something",
            url: url,
            price: price,
            currency: currency,
            isFulfilled: isFulfilled,
            needsParse: needsParse
        )
    }
}
