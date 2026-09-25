import Foundation
import StoreKit
import Testing
@testable import CorbieCore

@Suite struct NetStoreServiceTests {
    private let dollars = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))

    private let identifiers = StoreProductIdentifiers(monthly: "app.corbie.monthly", yearly: "app.corbie.yearly")

    private func offer(_ product: CorbieProduct, _ price: String, display: String) -> SubscriptionOffer {
        SubscriptionOffer(
            product: product,
            productId: identifiers.identifier(for: product) ?? "",
            displayPrice: display,
            price: Decimal(string: price) ?? 0,
            priceFormatStyle: dollars
        )
    }

    @Test func productIdentifiersMapBothWays() {
        #expect(identifiers.all == ["app.corbie.monthly", "app.corbie.yearly"])
        #expect(identifiers.product(for: "app.corbie.yearly") == .yearly)
        #expect(identifiers.product(for: " app.corbie.monthly ") == .monthly)
        #expect(identifiers.product(for: "app.corbie.lifetime") == nil)
        #expect(identifiers.identifier(for: .monthly) == "app.corbie.monthly")
        #expect(CorbieProduct.monthly.monthsPerPeriod == 1)
        #expect(CorbieProduct.yearly.monthsPerPeriod == 12)
    }

    @Test func productIdentifiersComeFromTheBundleInfo() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("corbie-store-\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let info: [String: Any] = [
            "CFBundleIdentifier": "app.corbie.tests.store.\(UUID().uuidString)",
            StoreProductIdentifiers.monthlyInfoKey: " shop.monthly ",
            StoreProductIdentifiers.yearlyInfoKey: "shop.yearly"
        ]
        let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try plist.write(to: folder.appendingPathComponent("Info.plist"))
        let bundle = try #require(Bundle(url: folder))

        let configured = StoreProductIdentifiers(bundle: bundle)
        #expect(configured.all == ["shop.monthly", "shop.yearly"])
        #expect(configured.product(for: "shop.yearly") == .yearly)
        #expect(StoreService(productIdentifiers: configured).productIdentifiers == configured)
    }

    @Test func aBundleWithoutProductIdentifiersOffersNothing() {
        let missing = StoreProductIdentifiers(bundle: Bundle(for: BundleMarker.self))
        #expect(missing.all.isEmpty)
        #expect(missing.product(for: "app.corbie.yearly") == nil)
        #expect(StoreProductIdentifiers(monthly: " ", yearly: "app.corbie.yearly").all == ["app.corbie.yearly"])
    }

    @Test func theYearlyPlanSavesHalfTheMonthlyPrice() {
        #expect(SubscriptionOfferMath.savingsPercent(
            monthly: Decimal(string: "4.99") ?? 0,
            yearly: Decimal(string: "29.99") ?? 0
        ) == 50)
        #expect(SubscriptionOfferMath.savingsPercent(
            monthly: Decimal(string: "5.99") ?? 0,
            yearly: Decimal(string: "39.99") ?? 0
        ) == 44)
    }

    @Test func aYearlyPlanThatSavesNothingCarriesNoBadge() {
        #expect(SubscriptionOfferMath.savingsPercent(monthly: 5, yearly: 60) == nil)
        #expect(SubscriptionOfferMath.savingsPercent(monthly: 5, yearly: 90) == nil)
        #expect(SubscriptionOfferMath.savingsPercent(monthly: 0, yearly: 29) == nil)
        #expect(SubscriptionOfferMath.savingsPercent(monthly: 5, yearly: 0) == nil)
    }

    @Test func savingsLandOnTheYearlyOfferOnly() {
        let offers = SubscriptionOfferMath.applySavings(to: [
            offer(.monthly, "4.99", display: "$4.99"),
            offer(.yearly, "29.99", display: "$29.99")
        ])
        #expect(offers.first(where: { $0.product == .monthly })?.savingsPercent == nil)
        #expect(offers.first(where: { $0.product == .yearly })?.savingsPercent == 50)

        let lonely = SubscriptionOfferMath.applySavings(to: [offer(.yearly, "29.99", display: "$29.99")])
        #expect(lonely.first?.savingsPercent == nil)
    }

    @Test func onlyAMultiMonthPlanHasAMonthlyPrice() {
        let yearly = Decimal(string: "29.99") ?? 0
        #expect(SubscriptionOfferMath.monthlyEquivalent(offer(.yearly, "29.99", display: "$29.99")) == yearly / 12)
        #expect(SubscriptionOfferMath.monthlyEquivalent(offer(.monthly, "4.99", display: "$4.99")) == nil)
        #expect(SubscriptionOfferMath.monthlyEquivalent(offer(.yearly, "0", display: "free")) == nil)
    }

    @Test func theYearlyOfferIsShownFirst() {
        let sorted = SubscriptionOfferMath.sorted([
            offer(.monthly, "4.99", display: "$4.99"),
            offer(.yearly, "29.99", display: "$29.99")
        ])
        #expect(sorted.map(\.product) == [.yearly, .monthly])
        #expect(sorted.first?.id == "app.corbie.yearly")
        #expect(sorted.first?.productId == "app.corbie.yearly")
    }

    @Test func aLocalEntitlementKnowsWhenItIsStillGood() {
        let now = NetTestSupport.date("2026-09-05T10:00:00Z")
        #expect(LocalEntitlement(productId: "app.corbie.yearly").isActive(at: now))
        #expect(LocalEntitlement(productId: "app.corbie.yearly", expiresAt: now.addingTimeInterval(60)).isActive(at: now))
        #expect(LocalEntitlement(productId: "app.corbie.yearly", expiresAt: now).isActive(at: now) == false)
        #expect(LocalEntitlement(productId: "app.corbie.yearly", renewal: .revoked).isActive(at: now) == false)
        #expect(LocalEntitlement(productId: "app.corbie.yearly", renewal: .expired).isActive(at: now) == false)
        #expect(LocalEntitlement(productId: "app.corbie.yearly", renewal: .inGracePeriod).isActive(at: now) == false)
    }

    @Test func fourteenFreeDaysComeOutOfATwoWeekIntroPeriod() {
        #expect(SubscriptionOfferMath.freeTrialDays(unit: .week, value: 2, periodCount: 1) == 14)
        #expect(SubscriptionOfferMath.freeTrialDays(unit: .day, value: 14, periodCount: 1) == 14)
        #expect(SubscriptionOfferMath.freeTrialDays(unit: .month, value: 1, periodCount: 1) == 30)
        #expect(SubscriptionOfferMath.freeTrialDays(unit: .week, value: 1, periodCount: 2) == 14)
        #expect(SubscriptionOfferMath.freeTrialDays(unit: .week, value: 0, periodCount: 1) == nil)
    }

    @Test func theSavingsBadgeSurvivesAnEligibleTrial() {
        let offers = SubscriptionOfferMath.applySavings(to: [
            SubscriptionOffer(
                product: .monthly,
                productId: "app.corbie.monthly",
                displayPrice: "$4.99",
                price: Decimal(string: "4.99") ?? 0,
                priceFormatStyle: dollars,
                eligibleFreeTrialDays: 14
            ),
            SubscriptionOffer(
                product: .yearly,
                productId: "app.corbie.yearly",
                displayPrice: "$29.99",
                price: Decimal(string: "29.99") ?? 0,
                priceFormatStyle: dollars,
                eligibleFreeTrialDays: 14
            )
        ])
        let yearly = offers.first { $0.product == .yearly }
        #expect(yearly?.savingsPercent == 50)
        #expect(yearly?.eligibleFreeTrialDays == 14)
    }

    @Test func aRevokedTransactionBeatsTheRenewalState() {
        #expect(StoreService.renewalState(nil, isRevoked: true) == .revoked)
        #expect(StoreService.renewalState(nil, isRevoked: false) == .subscribed)
        #expect(StoreService.renewalState(.subscribed, isRevoked: true) == .revoked)
        #expect(StoreService.renewalState(.subscribed, isRevoked: false) == .subscribed)
        #expect(StoreService.renewalState(.inGracePeriod, isRevoked: false) == .inGracePeriod)
        #expect(StoreService.renewalState(.inBillingRetryPeriod, isRevoked: false) == .inBillingRetry)
        #expect(StoreService.renewalState(.expired, isRevoked: false) == .expired)
        #expect(StoreService.renewalState(.revoked, isRevoked: false) == .revoked)
    }

    @Test func theLatestTransactionWins() {
        let now = NetTestSupport.date("2026-09-05T10:00:00Z")
        let older = LocalEntitlement(productId: "app.corbie.monthly", expiresAt: now.addingTimeInterval(86_400))
        let newer = LocalEntitlement(productId: "app.corbie.yearly", expiresAt: now.addingTimeInterval(360 * 86_400))
        let forever = LocalEntitlement(productId: "app.corbie.yearly")
        #expect(LocalEntitlement.isNewer(newer, than: older))
        #expect(LocalEntitlement.isNewer(older, than: newer) == false)
        #expect(LocalEntitlement.isNewer(older, than: nil))
        #expect(LocalEntitlement.isNewer(forever, than: newer))
    }

    @Test func theEnvironmentNamesMatchTheServer() {
        #expect(StoreEnvironment.allCases.map(\.rawValue) == ["Production", "Sandbox", "Xcode"])
        #expect(StoreEnvironmentRule.readable(nil) == .production)
        #expect(StoreEnvironmentRule.mayWriteMirror(nil) == false)
        let sandbox = AppTransactionProof(environment: .sandbox, signedAppTransaction: "jws")
        let production = AppTransactionProof(environment: .production, signedAppTransaction: "jws")
        #expect(StoreEnvironmentRule.readable(sandbox) == .sandbox)
        #expect(StoreEnvironmentRule.mayWriteMirror(sandbox) == false)
        #expect(StoreEnvironmentRule.mayWriteMirror(production))
    }
}

private final class BundleMarker {}
