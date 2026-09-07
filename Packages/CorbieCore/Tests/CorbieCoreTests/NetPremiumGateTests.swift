import Foundation
import Testing
@testable import CorbieCore

@MainActor
@Suite struct NetPremiumGateTests {
    private func gate(_ state: EntitlementState, analytics: RecordingAnalytics) -> PremiumGate {
        PremiumGate(
            state: state,
            analytics: analytics,
            makeId: { UUID(uuidString: "aa000000-0000-4000-8000-000000000001") ?? UUID() },
            now: { NetTestSupport.date("2026-09-05T10:00:00Z") }
        )
    }

    @Test func calendarIsNeverGated() {
        let analytics = RecordingAnalytics()
        let readOnly = gate(.readOnly, analytics: analytics)
        #expect(readOnly.require(.calendar))
        #expect(readOnly.pendingPaywall == nil)
        #expect(analytics.events.isEmpty)
    }

    @Test func theFreeTierIsCalendarOnly() {
        #expect(PremiumAction.allCases.filter { $0.isGated == false } == [.calendar])
    }

    @Test func theAmendedPremiumFeaturesAreGated() {
        let analytics = RecordingAnalytics()
        let readOnly = gate(.readOnly, analytics: analytics)
        #expect(readOnly.require(.freeTime) == false)
        #expect(readOnly.pendingPaywall?.reason == .freeTime)
        readOnly.dismissPaywall()
        #expect(readOnly.require(.freeTime) == false)
        #expect(readOnly.pendingPaywall?.reason == .freeTime)
        #expect(analytics.events.contains(.readonlyHit(feature: .freeTime)))
        #expect(analytics.events.contains(.paywallDismissed(screen: .comparison)))
    }

    @Test func aReadOnlySpaceAsksForThePaywallAndReportsIt() {
        let analytics = RecordingAnalytics()
        let readOnly = gate(.readOnly, analytics: analytics)
        #expect(readOnly.isReadOnly)
        #expect(readOnly.isPremium == false)
        #expect(readOnly.trialDaysLeft == nil)

        #expect(readOnly.require(.create) == false)
        let request = readOnly.pendingPaywall
        #expect(request?.reason == .create)
        #expect(request?.action == .create)
        #expect(request?.requestedAt == NetTestSupport.date("2026-09-05T10:00:00Z"))
        #expect(analytics.names == ["comparison_shown", "readonly_hit"])
        #expect(analytics.events.first == .comparisonShown(reason: .create))
        #expect(analytics.events.last == .readonlyHit(feature: .create))
    }

    @Test func everyGatedActionHasItsOwnReason() {
        for action in PremiumAction.allCases where action.isGated {
            let analytics = RecordingAnalytics()
            let readOnly = gate(.readOnly, analytics: analytics)
            #expect(readOnly.require(action) == false)
            #expect(readOnly.pendingPaywall?.reason == action.paywallReason)
            #expect(analytics.events.contains(.readonlyHit(feature: action)))
        }
        #expect(PremiumAction.calendar.isGated == false)
    }

    @Test func aTrialLetsEverythingThrough() {
        let analytics = RecordingAnalytics()
        let trial = gate(.trial(daysLeft: 2, endsAt: NetTestSupport.date("2026-09-07T10:00:00Z")), analytics: analytics)
        #expect(trial.isPremium)
        #expect(trial.trialDaysLeft == 2)
        #expect(trial.state.isTrialEndingSoon)
        for action in PremiumAction.allCases {
            #expect(trial.require(action))
        }
        #expect(trial.pendingPaywall == nil)
        #expect(analytics.events.isEmpty)
    }

    @Test func aSubscribedSpaceLetsEverythingThrough() {
        let analytics = RecordingAnalytics()
        let active = gate(.premium(source: .server, expiresAt: nil), analytics: analytics)
        #expect(active.isPremium)
        #expect(active.state.isTrialEndingSoon == false)
        #expect(active.require(.capsules))
        #expect(analytics.events.isEmpty)

        let grace = gate(.grace(expiresAt: nil), analytics: analytics)
        #expect(grace.require(.widgets))
        #expect(analytics.events.isEmpty)
    }

    @Test func openingThePaywallFromSettingsReportsTheReasonOnly() {
        let analytics = RecordingAnalytics()
        let readOnly = gate(.readOnly, analytics: analytics)
        readOnly.presentPaywall(reason: .settings)
        #expect(readOnly.pendingPaywall?.reason == .settings)
        #expect(readOnly.pendingPaywall?.action == nil)
        #expect(analytics.names == ["comparison_shown"])
        readOnly.dismissPaywall(screen: .trialOffer)
        #expect(readOnly.pendingPaywall == nil)
        #expect(analytics.names == ["comparison_shown", "paywall_dismissed"])
    }

    @Test func enteringTheGracePeriodIsReportedOnce() {
        let analytics = RecordingAnalytics()
        let active = gate(.premium(source: .storeKit, expiresAt: nil), analytics: analytics)
        active.update(.grace(expiresAt: nil))
        active.update(.grace(expiresAt: NetTestSupport.date("2026-09-09T10:00:00Z")))
        #expect(analytics.names == ["grace_period_entered"])
        active.update(.readOnly)
        active.update(.grace(expiresAt: nil))
        #expect(analytics.names == ["grace_period_entered", "grace_period_entered"])
    }

    @Test func aPurchaseClosesAnOpenPaywall() {
        let analytics = RecordingAnalytics()
        let readOnly = gate(.readOnly, analytics: analytics)
        #expect(readOnly.require(.edit) == false)
        #expect(readOnly.pendingPaywall != nil)
        readOnly.update(.premium(source: .storeKit, expiresAt: nil))
        #expect(readOnly.pendingPaywall == nil)
        #expect(readOnly.isPremium)
        #expect(readOnly.require(.edit))
    }
}

#if DEBUG
@Suite struct NetDebugEntitlementOverrideTests {
    private let now = NetTestSupport.date("2026-09-05T10:00:00Z")

    @Test func everyForcedStateIsReachable() {
        #expect(DebugEntitlementOverride.premium.state(now: now) == .premium(source: .storeKit, expiresAt: nil))
        #expect(DebugEntitlementOverride.trialEnding.state(now: now) == .trial(
            daysLeft: PremiumGate.trialNoticeDays,
            endsAt: now.addingTimeInterval(Double(PremiumGate.trialNoticeDays) * 86_400)
        ))
        #expect(DebugEntitlementOverride.readOnly.state(now: now) == .readOnly)
        #expect(DebugEntitlementOverride.gracePeriod.state(now: now) == .grace(
            expiresAt: now.addingTimeInterval(Double(DebugEntitlementOverride.gracePeriodDays) * 86_400)
        ))
        #expect(DebugEntitlementOverride.allCases.count == 5)
    }

    @Test func onlyTheIneligibleOverrideTouchesTheIntroOffer() {
        #expect(DebugEntitlementOverride.introOfferUsed.hidesIntroOffer)
        #expect(DebugEntitlementOverride.introOfferUsed.state(now: now) == nil)
        for override in DebugEntitlementOverride.allCases where override != .introOfferUsed {
            #expect(override.hidesIntroOffer == false)
            #expect(override.state(now: now) != nil)
        }
    }

    @Test func theOverrideRoundTripsThroughItsOwnSuite() {
        let name = "corbie.tests." + UUID().uuidString
        let defaults = NetTestSupport.defaults(name)
        #expect(DebugEntitlementOverride.stored(suiteName: name) == nil)
        DebugEntitlementOverride.store(.gracePeriod, suiteName: name)
        #expect(DebugEntitlementOverride.stored(suiteName: name) == .gracePeriod)
        DebugEntitlementOverride.store(nil, suiteName: name)
        #expect(DebugEntitlementOverride.stored(suiteName: name) == nil)
        NetTestSupport.removeDefaults(defaults, name: name)
    }
}
#endif
