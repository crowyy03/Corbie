import Foundation
import Observation

public enum PremiumAction: String, Sendable, Equatable, CaseIterable, Codable {
    case create
    case edit
    case widgets
    case capsules
    case votes
    case people
    case freeTime = "free_time"
    case calendar

    public var isGated: Bool {
        switch self {
        case .calendar: return false
        case .create, .edit, .widgets, .capsules, .votes, .people, .freeTime: return true
        }
    }

    public var paywallReason: PaywallReason {
        switch self {
        case .create: return .create
        case .edit: return .edit
        case .widgets: return .widgets
        case .capsules: return .capsules
        case .votes: return .votes
        case .people: return .people
        case .freeTime: return .freeTime
        case .calendar: return .settings
        }
    }
}

public enum PaywallReason: String, Sendable, Equatable, CaseIterable, Codable {
    case trialEnding = "trial_ending"
    case trialEnded = "trial_ended"
    case settings
    case create
    case edit
    case widgets
    case capsules
    case votes
    case people
    case freeTime = "free_time"
}

public enum PaywallScreen: String, Sendable, Equatable, CaseIterable, Codable {
    case trialOffer = "trial_offer"
    case comparison
}

public struct PaywallRequest: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let reason: PaywallReason
    public let action: PremiumAction?
    public let requestedAt: Date

    public init(id: UUID = UUID(), reason: PaywallReason, action: PremiumAction? = nil, requestedAt: Date = Date()) {
        self.id = id
        self.reason = reason
        self.action = action
        self.requestedAt = requestedAt
    }
}

@Observable @MainActor
public final class PremiumGate {
    public nonisolated static let trialNoticeDays = 2

    public private(set) var state: EntitlementState
    public var pendingPaywall: PaywallRequest?

    @ObservationIgnored private let analytics: any AnalyticsRecording
    @ObservationIgnored private let entitlements: EntitlementService?
    @ObservationIgnored private let makeId: @Sendable () -> UUID
    @ObservationIgnored private let now: @Sendable () -> Date

    public init(
        state: EntitlementState = .readOnly,
        analytics: any AnalyticsRecording,
        entitlements: EntitlementService? = nil,
        makeId: @escaping @Sendable () -> UUID = { UUID() },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.state = state
        self.analytics = analytics
        self.entitlements = entitlements
        self.makeId = makeId
        self.now = now
    }

    public var isPremium: Bool { state.isPremium }
    public var isReadOnly: Bool { state.isReadOnly }
    public var trialDaysLeft: Int? { state.trialDaysLeft }
    public var trialEndsAt: Date? { state.trialEndsAt }

    @discardableResult
    public func require(_ action: PremiumAction) -> Bool {
        guard action.isGated else { return true }
        guard isPremium == false else { return true }
        pendingPaywall = PaywallRequest(
            id: makeId(),
            reason: action.paywallReason,
            action: action,
            requestedAt: now()
        )
        analytics.record(.comparisonShown(reason: action.paywallReason))
        analytics.record(.readonlyHit(feature: action))
        return false
    }

    public func presentPaywall(reason: PaywallReason) {
        pendingPaywall = PaywallRequest(id: makeId(), reason: reason, action: nil, requestedAt: now())
        analytics.record(.comparisonShown(reason: reason))
    }

    public func dismissPaywall(screen: PaywallScreen = .comparison) {
        guard pendingPaywall != nil else { return }
        pendingPaywall = nil
        analytics.record(.paywallDismissed(screen: screen))
    }

    public func update(_ newState: EntitlementState) {
        let wasInGracePeriod = PremiumGate.isGrace(state)
        state = newState
        if PremiumGate.isGrace(newState), wasInGracePeriod == false {
            analytics.record(.gracePeriodEntered)
        }
        if newState.isPremium {
            pendingPaywall = nil
        }
    }

    public func refresh(spaceId: UUID) async {
        guard let entitlements else { return }
        update(await entitlements.refresh(spaceId: spaceId))
    }

    private static func isGrace(_ state: EntitlementState) -> Bool {
        guard case .grace = state else { return false }
        return true
    }
}
