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
        #expect(analytics.names == ["paywall_shown", "readonly_hit"])
        #expect(analytics.events.first == .paywallShown(reason: .create))
        #expect(analytics.events.last == .readonlyHit(action: .create))
    }

    @Test func everyGatedActionHasItsOwnReason() {
        for action in PremiumAction.allCases where action.isGated {
            let analytics = RecordingAnalytics()
            let readOnly = gate(.readOnly, analytics: analytics)
            #expect(readOnly.require(action) == false)
            #expect(readOnly.pendingPaywall?.reason == action.paywallReason)
            #expect(analytics.events.contains(.readonlyHit(action: action)))
        }
        #expect(PremiumAction.calendar.isGated == false)
    }

    @Test func aTrialLetsEverythingThrough() {
        let analytics = RecordingAnalytics()
        let trial = gate(.trial(daysLeft: 2), analytics: analytics)
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
        let active = gate(.active(source: .server, expiresAt: nil), analytics: analytics)
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
        #expect(analytics.names == ["paywall_shown"])
        readOnly.dismissPaywall()
        #expect(readOnly.pendingPaywall == nil)
    }

    @Test func aPurchaseClosesAnOpenPaywall() {
        let analytics = RecordingAnalytics()
        let readOnly = gate(.readOnly, analytics: analytics)
        #expect(readOnly.require(.edit) == false)
        #expect(readOnly.pendingPaywall != nil)
        readOnly.update(.active(source: .storeKit, expiresAt: nil))
        #expect(readOnly.pendingPaywall == nil)
        #expect(readOnly.isPremium)
        #expect(readOnly.require(.edit))
    }
}
