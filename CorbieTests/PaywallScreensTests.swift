import CorbieCore
import XCTest
@testable import Corbie

final class PaywallScreensTests: XCTestCase {
    private let dollars = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))
    private let euros = Decimal.FormatStyle.Currency(code: "EUR", locale: Locale(identifier: "de_DE"))

    private func offers(
        monthly: String,
        yearly: String,
        style: Decimal.FormatStyle.Currency,
        trialDays: Int? = nil
    ) -> [SubscriptionOffer] {
        SubscriptionOfferMath.sorted(
            SubscriptionOfferMath.applySavings(to: [
                SubscriptionOffer(
                    product: .monthly,
                    productId: "test.monthly",
                    displayPrice: (Decimal(string: monthly) ?? 0).formatted(style),
                    price: Decimal(string: monthly) ?? 0,
                    priceFormatStyle: style,
                    eligibleFreeTrialDays: trialDays
                ),
                SubscriptionOffer(
                    product: .yearly,
                    productId: "test.yearly",
                    displayPrice: (Decimal(string: yearly) ?? 0).formatted(style),
                    price: Decimal(string: yearly) ?? 0,
                    priceFormatStyle: style,
                    eligibleFreeTrialDays: trialDays
                )
            ])
        )
    }

    private func yearly(_ offers: [SubscriptionOffer]) -> SubscriptionOffer? {
        offers.first { $0.product == .yearly }
    }

    private func monthly(_ offers: [SubscriptionOffer]) -> SubscriptionOffer? {
        offers.first { $0.product == .monthly }
    }

    func testTheYearlyCardLeadsTheSelector() {
        let sorted = offers(monthly: "4.99", yearly: "29.99", style: dollars)
        XCTAssertEqual(sorted.map(\.product), [.yearly, .monthly])
    }

    func testTheStruckPriceIsTwelveMonthlyPaymentsInDollars() throws {
        let sorted = offers(monthly: "4.99", yearly: "29.99", style: dollars)
        let year = try XCTUnwrap(yearly(sorted))
        XCTAssertEqual(PaywallCopy.yearAtMonthlyPrice(for: year, monthly: monthly(sorted)), "$59.88")
        XCTAssertEqual(PaywallCopy.savingsBadge(for: year), "Save 50%")
        XCTAssertEqual(PaywallCopy.monthlyEquivalent(for: year), "$2.50 a month")
    }

    func testTheStruckPriceFollowsTheStorefrontCurrencyAndSeparators() throws {
        let sorted = offers(monthly: "5.99", yearly: "39.99", style: euros)
        let year = try XCTUnwrap(yearly(sorted))
        let struck = try XCTUnwrap(PaywallCopy.yearAtMonthlyPrice(for: year, monthly: monthly(sorted)))
        XCTAssertTrue(struck.hasPrefix("71,88"), struck)
        XCTAssertTrue(struck.contains("€"), struck)
        XCTAssertFalse(struck.contains("$"), struck)
        XCTAssertEqual(year.savingsPercent, 44)
        XCTAssertEqual(Decimal(string: "71.88"), SubscriptionOfferMath.twelveMonths(of: Decimal(string: "5.99") ?? 0))
    }

    func testTheMonthlyCardCarriesNoStruckPriceAndNoBadge() throws {
        let sorted = offers(monthly: "4.99", yearly: "29.99", style: dollars)
        let month = try XCTUnwrap(monthly(sorted))
        XCTAssertNil(PaywallCopy.yearAtMonthlyPrice(for: month, monthly: month))
        XCTAssertNil(PaywallCopy.savingsBadge(for: month))
        XCTAssertNil(PaywallCopy.monthlyEquivalent(for: month))
    }

    func testAYearThatCostsAsMuchAsTwelveMonthsShowsNothingToCompare() throws {
        let sorted = offers(monthly: "4.99", yearly: "59.88", style: dollars)
        let year = try XCTUnwrap(yearly(sorted))
        XCTAssertNil(year.savingsPercent)
        XCTAssertNil(PaywallCopy.yearAtMonthlyPrice(for: year, monthly: monthly(sorted)))
    }

    func testAnEligibleBuyerIsOfferedTheTrialWithTheStorePriceUnderTheButton() throws {
        let sorted = offers(monthly: "4.99", yearly: "29.99", style: dollars, trialDays: 14)
        let year = try XCTUnwrap(yearly(sorted))
        let month = try XCTUnwrap(monthly(sorted))
        XCTAssertEqual(PaywallCopy.callToAction(for: year), "Start free trial")
        XCTAssertEqual(PaywallCopy.trialTerms(for: year), "14 days free, then $29.99/year")
        XCTAssertEqual(PaywallCopy.callToAction(for: month), "Start free trial")
        XCTAssertEqual(PaywallCopy.trialTerms(for: month), "14 days free, then $4.99/month")
    }

    func testAnIneligibleBuyerSeesSubscribeAndNoWordAboutATrial() throws {
        let sorted = offers(monthly: "4.99", yearly: "29.99", style: dollars)
        for offer in sorted {
            XCTAssertEqual(PaywallCopy.callToAction(for: offer), "Subscribe")
            XCTAssertNil(PaywallCopy.trialTerms(for: offer))
            let legal = PaywallCopy.legalText(for: offer).lowercased()
            XCTAssertFalse(legal.contains("trial"), legal)
            XCTAssertFalse(legal.contains("free"), legal)
        }
        XCTAssertEqual(PaywallCopy.callToAction(for: nil), "Subscribe")
        XCTAssertNil(PaywallCopy.trialTerms(for: nil))
    }

    func testTheTermsCountTheDaysTheOfferActuallyGives() throws {
        let week = try XCTUnwrap(yearly(offers(monthly: "4.99", yearly: "29.99", style: dollars, trialDays: 7)))
        XCTAssertEqual(PaywallCopy.trialTerms(for: week), "7 days free, then $29.99/year")
        let euro = try XCTUnwrap(yearly(offers(monthly: "5.99", yearly: "39.99", style: euros, trialDays: 14)))
        let terms = try XCTUnwrap(PaywallCopy.trialTerms(for: euro))
        XCTAssertTrue(terms.contains(euro.displayPrice), terms)
    }

    func testTheComparisonHeaderSaysWhatEnded() {
        XCTAssertEqual(PaywallCopy.headerKey(.readOnly, cause: .trialEnded), "paywall.compare.trialended")
        XCTAssertEqual(
            PaywallCopy.text("paywall.compare.trialended"),
            "Your trial has ended. Everything you made is still here."
        )
        XCTAssertEqual(PaywallCopy.headerKey(.readOnly, cause: .subscriptionEnded), "paywall.compare.subscriptionended")
        XCTAssertEqual(
            PaywallCopy.text("paywall.compare.subscriptionended"),
            "Your subscription has ended. Everything you made is still here."
        )
        XCTAssertEqual(PaywallCopy.headerKey(.readOnly, cause: .neverSubscribed), "paywall.headline")
        XCTAssertEqual(PaywallCopy.headerKey(.readOnly, cause: nil), "paywall.headline")
        for reason in PaywallReason.allCases where reason != .readOnly {
            for cause in ReadOnlyCause.allCases {
                XCTAssertEqual(PaywallCopy.headerKey(reason, cause: cause), "paywall.headline")
            }
        }
    }

    func testTheComparisonTableHasSevenRowsAndFourFreeOnes() {
        XCTAssertEqual(ComparisonRow.all.count, 7)
        XCTAssertEqual(ComparisonRow.all.compactMap(\.freeKey).count, 4)
        for row in ComparisonRow.all {
            XCTAssertNotEqual(PaywallCopy.text(row.premiumKey), row.premiumKey, "missing value for \(row.premiumKey)")
            guard let freeKey = row.freeKey else { continue }
            XCTAssertNotEqual(PaywallCopy.text(freeKey), freeKey, "missing value for \(freeKey)")
        }
    }

    func testThePaywallAfterTheFreeWindowIsClaimedOnceForASpace() throws {
        let suite = "corbie.tests.freewindowpaywall." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let space = UUID()

        let flag = FreeWindowPaywallFlag(defaults: defaults)
        XCTAssertFalse(flag.hasBeenShown(spaceId: space))
        XCTAssertTrue(flag.claim(spaceId: space))
        XCTAssertTrue(flag.hasBeenShown(spaceId: space))
        XCTAssertFalse(flag.claim(spaceId: space))
        XCTAssertFalse(FreeWindowPaywallFlag(defaults: defaults).claim(spaceId: space))
        XCTAssertTrue(FreeWindowPaywallFlag(defaults: defaults).claim(spaceId: UUID()))
    }

    func testTheOneVersionZeroFlagDoesNotSilenceThePaywallAfterTheWindow() throws {
        let suite = "corbie.tests.freewindowpaywall." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "corbie.paywall.trialOfferShown")

        XCTAssertTrue(FreeWindowPaywallFlag(defaults: defaults).claim(spaceId: UUID()))
    }

    func testNoPaywallOrTrialScreenWhileTheWindowIsOpen() {
        let window = EntitlementState.freeWindow(FreeWindow(endsAt: Date().addingTimeInterval(86_400)))
        XCTAssertFalse(FreeWindowPaywallFlag.mayClaim(window))
        XCTAssertFalse(FreeWindowPaywallFlag.mayClaim(.monetizationOff))
        XCTAssertFalse(FreeWindowPaywallFlag.mayClaim(.premium(source: .storeKit, expiresAt: nil)))
        XCTAssertFalse(FreeWindowPaywallFlag.mayClaim(.trial(daysLeft: 14, endsAt: Date().addingTimeInterval(14 * 86_400))))
        XCTAssertTrue(FreeWindowPaywallFlag.mayClaim(.readOnly))
        XCTAssertNil(PaywallBannerState.make(window, cause: nil))
    }
}
