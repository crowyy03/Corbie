import CorbieCore
import XCTest
@testable import Corbie

final class PaywallCopyTests: XCTestCase {
    private let english = Locale(identifier: "en_US")

    private func offer(_ product: CorbieProduct, _ price: String, display: String, savings: Int? = nil) -> SubscriptionOffer {
        SubscriptionOffer(
            product: product,
            displayPrice: display,
            price: Decimal(string: price) ?? 0,
            currencyCode: "USD",
            savingsPercent: savings
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
        XCTAssertEqual(PaywallCopy.reasonKey(.trialEnded), "paywall.reason.trialended")
        XCTAssertEqual(PaywallCopy.reasonText(.trialEnded), "The trial is over. The calendar and Today still work.")
    }

    func testEveryValueRowResolves() {
        XCTAssertEqual(PaywallValueRow.all.map(\.id), ["widgets", "goals", "capsules"])
        for row in PaywallValueRow.all {
            for key in [row.titleKey, row.noteKey] {
                XCTAssertNotEqual(PaywallCopy.text(key), key, "missing catalog value for \(key)")
            }
        }
        XCTAssertEqual(PaywallCopy.text("paywall.value.goals.title"), "Goals and folders")
        XCTAssertEqual(PaywallCopy.text("paywall.value.capsules.title"), "Capsules and votes")
    }

    func testTheFeaturesTheAmendmentMadePremiumHaveTheirOwnLine() {
        XCTAssertEqual(PaywallCopy.reasonText(PremiumAction.folders.paywallReason), "Task folders come with the subscription.")
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
            PaywallCopy.monthlyEquivalent(for: offer(.yearly, "29.99", display: "$29.99"), locale: english),
            "$2.50 a month"
        )
        XCTAssertNil(PaywallCopy.monthlyEquivalent(for: offer(.monthly, "4.99", display: "$4.99"), locale: english))
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
            let text = PaywallCopy.text(PaywallCopy.legalKey(product))
            XCTAssertTrue(text.contains("Apple ID"), "\(product) is missing the billing account")
            XCTAssertTrue(text.contains("auto-renew"), "\(product) is missing the renewal terms")
            XCTAssertTrue(text.contains("24 hours"), "\(product) is missing the cancellation window")
        }
    }

    func testTheLegalLinksPointAtOurPages() {
        XCTAssertEqual(LegalPage.privacy.url?.absoluteString, "https://corbie.app/privacy")
        XCTAssertEqual(LegalPage.terms.url?.absoluteString, "https://corbie.app/terms")
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
            "paywall.action.continue",
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
