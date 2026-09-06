import Foundation
import Observation

public enum PremiumAction: String, Sendable, Equatable, CaseIterable, Codable {
    case create
    case edit
    case widgets
    case capsules
    case votes
    case people
    case calendar

    public var isGated: Bool { self != .calendar }

    public var paywallReason: PaywallReason {
        switch self {
        case .create: return .create
        case .edit: return .edit
        case .widgets: return .widgets
        case .capsules: return .capsules
        case .votes: return .votes
        case .people: return .people
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
        analytics: any AnalyticsRecording = Analytics.shared,
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
    public var isTrialEndingSoon: Bool { (state.trialDaysLeft ?? .max) <= PremiumGate.trialNoticeDays }

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
        analytics.record(.paywallShown(reason: action.paywallReason))
        analytics.record(.readonlyHit(action: action))
        return false
    }

    public func presentPaywall(reason: PaywallReason) {
        pendingPaywall = PaywallRequest(id: makeId(), reason: reason, action: nil, requestedAt: now())
        analytics.record(.paywallShown(reason: reason))
    }

    public func dismissPaywall() {
        pendingPaywall = nil
    }

    public func update(_ newState: EntitlementState) {
        state = newState
        if newState.isPremium {
            pendingPaywall = nil
        }
    }

    public func refresh(spaceId: UUID) async {
        guard let entitlements else { return }
        update(await entitlements.refresh(spaceId: spaceId))
    }
}
