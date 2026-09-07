import Foundation
import StoreKit
import Testing
@testable import CorbieCore

@Suite struct NetStoreServiceTests {
    private func offer(_ product: CorbieProduct, _ price: String, display: String) -> SubscriptionOffer {
        SubscriptionOffer(
            product: product,
            displayPrice: display,
            price: Decimal(string: price) ?? 0,
            currencyCode: "USD"
        )
    }

    @Test func productIdentifiersMapBothWays() {
        #expect(CorbieProduct.identifiers == ["app.corbie.monthly", "app.corbie.yearly"])
        #expect(CorbieProduct(identifier: "app.corbie.yearly") == .yearly)
        #expect(CorbieProduct(identifier: " app.corbie.monthly ") == .monthly)
        #expect(CorbieProduct(identifier: "app.corbie.lifetime") == nil)
        #expect(CorbieProduct.monthly.monthsPerPeriod == 1)
        #expect(CorbieProduct.yearly.monthsPerPeriod == 12)
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
                displayPrice: "$4.99",
                price: Decimal(string: "4.99") ?? 0,
                currencyCode: "USD",
                eligibleFreeTrialDays: 14
            ),
            SubscriptionOffer(
                product: .yearly,
                displayPrice: "$29.99",
                price: Decimal(string: "29.99") ?? 0,
                currencyCode: "USD",
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
        #expect(StoreService.isNewer(newer, than: older))
        #expect(StoreService.isNewer(older, than: newer) == false)
        #expect(StoreService.isNewer(older, than: nil))
        #expect(StoreService.isNewer(forever, than: newer))
    }
}
