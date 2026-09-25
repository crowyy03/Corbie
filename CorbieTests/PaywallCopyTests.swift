import CorbieCore
import XCTest
@testable import Corbie

final class PaywallCopyTests: XCTestCase {
    private let dollars = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))

    private func offer(
        _ product: CorbieProduct,
        _ price: String,
        display: String,
        savings: Int? = nil,
        trialDays: Int? = nil
    ) -> SubscriptionOffer {
        SubscriptionOffer(
            product: product,
            productId: "test.\(product.rawValue)",
            displayPrice: display,
            price: Decimal(string: price) ?? 0,
            priceFormatStyle: dollars,
            savingsPercent: savings,
            eligibleFreeTrialDays: trialDays
        )
    }

    func testEveryPaywallReasonHasItsOwnLine() {
        var seen: Set<String> = []
        for reason in PaywallReason.allCases {
            let key = PaywallCopy.reasonKey(reason)
            let text = PaywallCopy.text(key)
            XCTAssertNotEqual(text, key, "missing catalog value for \(key)")
            XCTAssertTrue(seen.insert(text).inserted, "duplicate reason line for \(reason)")
            XCTAssertFalse(text.contains("!"), "no exclamation marks in \(key)")
        }
    }

    func testTrialReasonsSayWhatHappened() {
        XCTAssertEqual(PaywallCopy.reasonKey(.trialEnding), "paywall.reason.trialending")
        XCTAssertEqual(PaywallCopy.reasonKey(.readOnly), "paywall.reason.readonly")
        XCTAssertEqual(PaywallCopy.reasonText(.readOnly), "The calendar and Today work without a subscription.")
    }

    func testEveryValueRowResolves() {
        XCTAssertEqual(
            PaywallValueRow.all.map(\.id),
            ["calendar", "tasks", "wishes", "plans", "question", "widgets"]
        )
        for row in PaywallValueRow.all {
            XCTAssertNotEqual(PaywallCopy.text(row.textKey), row.textKey, "missing catalog value for \(row.textKey)")
            XCTAssertFalse(row.systemImage.isEmpty)
        }
        XCTAssertEqual(PaywallCopy.text("paywall.value.plans"), "Plans and open savings")
    }

    func testFreeTimeHasItsOwnPaywallLine() {
        XCTAssertEqual(PaywallCopy.reasonText(PremiumAction.freeTime.paywallReason), "Free time comes with the subscription.")
    }

    func testTheSavingsBadgeCarriesTheRealPercent() {
        let offers = SubscriptionOfferMath.applySavings(to: [
            offer(.monthly, "4.99", display: "$4.99"),
            offer(.yearly, "29.99", display: "$29.99")
        ])
        guard let yearly = offers.first(where: { $0.product == .yearly }) else {
            return XCTFail("the yearly offer disappeared")
        }
        XCTAssertEqual(PaywallCopy.savingsBadge(for: yearly), "Save 50%")
        XCTAssertNil(PaywallCopy.savingsBadge(for: offer(.monthly, "4.99", display: "$4.99")))
    }

    func testOnlyTheLongerPlanShowsAMonthlyPrice() {
        XCTAssertEqual(
            PaywallCopy.monthlyEquivalent(for: offer(.yearly, "29.99", display: "$29.99")),
            "$2.50 a month"
        )
        XCTAssertNil(PaywallCopy.monthlyEquivalent(for: offer(.monthly, "4.99", display: "$4.99")))
    }

    func testTheLegalLineNamesThePriceAndThePeriod() {
        let yearly = PaywallCopy.legalText(for: offer(.yearly, "29.99", display: "$29.99"))
        XCTAssertTrue(yearly.contains("$29.99"))
        XCTAssertTrue(yearly.contains("year"))
        let monthly = PaywallCopy.legalText(for: offer(.monthly, "4.99", display: "$4.99"))
        XCTAssertTrue(monthly.contains("$4.99"))
        XCTAssertTrue(monthly.contains("month"))
        XCTAssertNotEqual(PaywallCopy.text("paywall.legal.generic"), "paywall.legal.generic")
    }

    func testTheLegalTextIsTheFullDisclosure() {
        for product in CorbieProduct.allCases {
            for key in [PaywallCopy.legalKey(product), PaywallCopy.trialLegalKey(product)] {
                let text = PaywallCopy.text(key)
                XCTAssertTrue(text.contains("Apple ID"), "\(key) is missing the billing account")
                XCTAssertTrue(text.contains("auto-renew"), "\(key) is missing the renewal terms")
                XCTAssertTrue(text.contains("24 hours"), "\(key) is missing the cancellation window")
            }
        }
    }

    func testATrialOfferSaysHowLongItIsFreeAndWhatItCostsAfter() {
        let yearly = PaywallCopy.legalText(for: offer(.yearly, "29.99", display: "$29.99", trialDays: 14))
        XCTAssertTrue(yearly.hasPrefix("14 days free, then $29.99 a year."), yearly)
        XCTAssertTrue(yearly.contains("charged when the trial ends"), yearly)
        XCTAssertFalse(yearly.contains("when you confirm"), yearly)

        let monthly = PaywallCopy.legalText(for: offer(.monthly, "4.99", display: "4,99 €", trialDays: 14))
        XCTAssertTrue(monthly.hasPrefix("14 days free, then 4,99 € a month."), monthly)

        let noTrial = PaywallCopy.legalText(for: offer(.yearly, "29.99", display: "$29.99"))
        XCTAssertTrue(noTrial.contains("charged when you confirm"), noTrial)
        XCTAssertFalse(noTrial.contains("free"), noTrial)
    }

    func testTheLegalLineNeverCarriesAnAmountOfItsOwn() {
        for product in CorbieProduct.allCases {
            for key in [PaywallCopy.legalKey(product), PaywallCopy.trialLegalKey(product)] {
                let text = PaywallCopy.text(key)
                XCTAssertNil(text.range(of: #"\d+[.,]\d{2}"#, options: .regularExpression), "\(key) prints an amount")
            }
        }
    }

    func testRestoreSaysWhatItFound() {
        XCTAssertEqual(PaywallCopy.restoreText(.restored), "Subscription restored.")
        XCTAssertEqual(PaywallCopy.restoreText(.nothingToRestore), "Nothing to restore on this Apple ID.")
    }

    func testTheLegalLinksPointAtOurPages() {
        XCTAssertEqual(LegalPage.privacy.url?.absoluteString, "https://yourcorbie.app/privacy")
        XCTAssertEqual(LegalPage.terms.url?.absoluteString, "https://yourcorbie.app/terms")
        for link in LegalPage.allCases {
            XCTAssertEqual(link.url?.scheme, "https")
            XCTAssertNotEqual(PaywallCopy.text(link.paywallTitleKey), link.paywallTitleKey)
        }
    }

    func testTheStateLinesExist() {
        let keys = [
            "paywall.state.loading",
            "paywall.state.unavailable",
            "paywall.state.nospace",
            "paywall.state.pending",
            "paywall.state.purchased",
            "paywall.state.restored",
            "paywall.state.restore.empty",
            "paywall.action.restore",
            "paywall.action.close",
            "paywall.action.retry",
            "paywall.headline"
        ]
        for key in keys {
            XCTAssertNotEqual(PaywallCopy.text(key), key, "missing catalog value for \(key)")
        }
    }
}
