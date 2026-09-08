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
                    displayPrice: (Decimal(string: monthly) ?? 0).formatted(style),
                    price: Decimal(string: monthly) ?? 0,
                    priceFormatStyle: style,
                    eligibleFreeTrialDays: trialDays
                ),
                SubscriptionOffer(
                    product: .yearly,
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

    func testTheCallToActionPromisesATrialOnlyWhenOneIsOffered() throws {
        let eligible = try XCTUnwrap(yearly(offers(monthly: "4.99", yearly: "29.99", style: dollars, trialDays: 14)))
        XCTAssertEqual(PaywallCopy.callToAction(for: eligible), "Try 14 days free")

        let ineligible = try XCTUnwrap(yearly(offers(monthly: "4.99", yearly: "29.99", style: dollars)))
        XCTAssertEqual(PaywallCopy.callToAction(for: ineligible), "Subscribe")
        XCTAssertEqual(PaywallCopy.callToAction(for: nil), "Subscribe")
    }

    func testTheCallToActionCountsTheDaysTheOfferActuallyGives() throws {
        let week = try XCTUnwrap(yearly(offers(monthly: "4.99", yearly: "29.99", style: dollars, trialDays: 7)))
        XCTAssertEqual(PaywallCopy.callToAction(for: week), "Try 7 days free")
    }

    func testTheComparisonHeaderChangesOnlyAfterTheTrialEnded() {
        XCTAssertEqual(PaywallCopy.headerKey(.trialEnded), "paywall.compare.expired")
        XCTAssertEqual(
            PaywallCopy.text("paywall.compare.expired"),
            "Your trial has ended. Everything you made is still here."
        )
        for reason in PaywallReason.allCases where reason != .trialEnded {
            XCTAssertEqual(PaywallCopy.headerKey(reason), "paywall.headline")
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

    func testTheTrialOfferIsClaimedOnceAndNeverAgain() throws {
        let suite = "corbie.tests.trialoffer." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let flag = TrialOfferFlag(defaults: defaults)
        XCTAssertFalse(flag.hasBeenShown)
        XCTAssertTrue(flag.claim())
        XCTAssertTrue(flag.hasBeenShown)
        XCTAssertFalse(flag.claim())
        XCTAssertFalse(TrialOfferFlag(defaults: defaults).claim())
    }

    func testAFreshInstallHasNotClaimedTheTrialOffer() throws {
        let suite = "corbie.tests.trialoffer." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertFalse(TrialOfferFlag(defaults: defaults).hasBeenShown)
        XCTAssertEqual(TrialOfferFlag.storageKey, "corbie.paywall.trialOfferShown")
    }
}
