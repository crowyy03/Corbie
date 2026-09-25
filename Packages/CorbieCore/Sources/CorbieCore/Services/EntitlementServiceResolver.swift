import Foundation

public enum EntitlementSource: String, Sendable, Equatable, CaseIterable, Codable {
    case storeKit
    case server
    case space
    case monetizationOff = "monetization_off"
}

public enum EntitlementState: Sendable, Equatable {
    case premium(source: EntitlementSource, expiresAt: Date?)
    case trial(daysLeft: Int, endsAt: Date)
    case grace(expiresAt: Date?)
    case readOnly

    public var isPremium: Bool {
        switch self {
        case .premium, .trial, .grace: return true
        case .readOnly: return false
        }
    }

    public var isReadOnly: Bool { isPremium == false }

    public static let monetizationOff = EntitlementState.premium(source: .monetizationOff, expiresAt: nil)

    public var isMonetizationOff: Bool { self == .monetizationOff }

    public var trialDaysLeft: Int? {
        guard case let .trial(daysLeft, _) = self else { return nil }
        return daysLeft
    }

    public var trialEndsAt: Date? {
        guard case let .trial(_, endsAt) = self else { return nil }
        return endsAt
    }

    public var isTrialEndingSoon: Bool { (trialDaysLeft ?? .max) <= PremiumGate.trialNoticeDays }

    public var expiresAt: Date? {
        switch self {
        case let .premium(_, expiresAt): return expiresAt
        case let .trial(_, endsAt): return endsAt
        case let .grace(expiresAt): return expiresAt
        case .readOnly: return nil
        }
    }
}

public enum ReadOnlyCause: String, Sendable, Equatable, CaseIterable, Codable {
    case neverSubscribed = "never_subscribed"
    case subscriptionEnded = "subscription_ended"
    case trialEnded = "trial_ended"
}

public struct EntitlementResolution: Sendable, Equatable {
    public let state: EntitlementState
    public let readOnlyCause: ReadOnlyCause?

    public init(state: EntitlementState, readOnlyCause: ReadOnlyCause? = nil) {
        self.state = state
        self.readOnlyCause = state.isReadOnly ? readOnlyCause ?? .neverSubscribed : nil
    }
}

public struct ServerEntitlement: Sendable, Equatable, Codable {
    public let status: EntitlementStatus
    public let productId: String?
    public let expiresAt: Date?
    public let updatedAt: Date?
    public let environment: StoreEnvironment?

    public init(
        status: EntitlementStatus,
        productId: String? = nil,
        expiresAt: Date? = nil,
        updatedAt: Date? = nil,
        environment: StoreEnvironment? = nil
    ) {
        self.status = status
        self.productId = productId
        self.expiresAt = expiresAt
        self.updatedAt = updatedAt
        self.environment = environment
    }

    public init(payload: EntitlementPayload) {
        self.init(
            status: payload.status,
            productId: payload.productId,
            expiresAt: payload.expiresAt,
            updatedAt: payload.updatedAt,
            environment: payload.environment
        )
    }

    public func isActive(at moment: Date) -> Bool {
        guard status == .active else { return false }
        guard let expiresAt else { return true }
        return expiresAt > moment
    }
}

public struct LocalEntitlement: Sendable, Equatable, Codable {
    public let productId: String
    public let renewal: StoreRenewalState
    public let expiresAt: Date?
    public let gracePeriodExpiresAt: Date?
    public let isInIntroOffer: Bool

    public init(
        productId: String,
        renewal: StoreRenewalState = .subscribed,
        expiresAt: Date? = nil,
        gracePeriodExpiresAt: Date? = nil,
        isInIntroOffer: Bool = false
    ) {
        self.productId = productId
        self.renewal = renewal
        self.expiresAt = expiresAt
        self.gracePeriodExpiresAt = gracePeriodExpiresAt
        self.isInIntroOffer = isInIntroOffer
    }

    public func isActive(at moment: Date) -> Bool {
        guard renewal == .subscribed else { return false }
        guard let expiresAt else { return true }
        return expiresAt > moment
    }

    public static func isNewer(_ candidate: LocalEntitlement, than current: LocalEntitlement?) -> Bool {
        guard let current else { return true }
        guard let candidateExpiry = candidate.expiresAt else { return true }
        guard let currentExpiry = current.expiresAt else { return false }
        return candidateExpiry > currentExpiry
    }
}

public struct MirroredEntitlement: Sendable, Equatable, Codable {
    public let status: SubscriptionStatus
    public let expiresAt: Date?

    public init(status: SubscriptionStatus, expiresAt: Date?) {
        self.status = status
        self.expiresAt = expiresAt
    }

    public init(space: SpaceDTO) {
        self.init(status: space.subscriptionStatus, expiresAt: space.subscriptionExpiresAt)
    }

    public func isPremium(at moment: Date) -> Bool {
        switch status {
        case .active:
            guard let expiresAt else { return true }
            return expiresAt > moment
        case .trial:
            guard let expiresAt else { return false }
            return expiresAt > moment
        case .none, .expired, .readonly:
            return false
        }
    }
}

public protocol LocalEntitlementProviding: Sendable {
    func subscriptions() async -> [StoreSubscription]
}

public struct EntitlementInputs: Sendable, Equatable {
    public var environment: StoreEnvironment
    public var local: LocalEntitlement?
    public var server: ServerEntitlement?
    public var space: MirroredEntitlement?
    public var now: Date

    public init(
        environment: StoreEnvironment = .production,
        local: LocalEntitlement? = nil,
        server: ServerEntitlement? = nil,
        space: MirroredEntitlement? = nil,
        now: Date = Date()
    ) {
        self.environment = environment
        self.local = local
        self.server = server
        self.space = space
        self.now = now
    }

    public var readableServer: ServerEntitlement? {
        guard let server, server.environment == environment else { return nil }
        return server
    }

    public var readableMirror: MirroredEntitlement? {
        environment == .production ? space : nil
    }
}

public enum EntitlementResolver {
    public static func resolution(_ inputs: EntitlementInputs) -> EntitlementResolution {
        let state = resolve(inputs)
        return EntitlementResolution(state: state, readOnlyCause: state.isReadOnly ? readOnlyCause(inputs) : nil)
    }

    public static func resolve(_ inputs: EntitlementInputs) -> EntitlementState {
        let now = inputs.now
        if let local = inputs.local {
            if local.renewal == .revoked { return .readOnly }
            if let state = storeKitState(local, now: now) { return state }
        }
        if let server = inputs.readableServer {
            if server.status == .revoked { return .readOnly }
            if let state = serverState(server, now: now) { return state }
        }
        if let space = inputs.readableMirror, let state = mirroredState(space, now: now) { return state }
        return .readOnly
    }

    public static func readOnlyCause(_ inputs: EntitlementInputs) -> ReadOnlyCause {
        if let local = inputs.local {
            return local.isInIntroOffer && local.renewal != .revoked ? .trialEnded : .subscriptionEnded
        }
        let server = inputs.readableServer
        let mirror = inputs.readableMirror
        if server?.status == .revoked { return .subscriptionEnded }
        if mirror?.status == .trial { return .trialEnded }
        if let server, server.status != .none { return .subscriptionEnded }
        if mirror?.status == .active || mirror?.status == .expired { return .subscriptionEnded }
        return .neverSubscribed
    }

    public static func storeKitState(_ local: LocalEntitlement, now: Date) -> EntitlementState? {
        switch local.renewal {
        case .subscribed:
            guard local.isActive(at: now) else { return nil }
            guard local.isInIntroOffer,
                  let endsAt = local.expiresAt,
                  let daysLeft = trialDaysLeft(endsAt: endsAt, now: now)
            else { return .premium(source: .storeKit, expiresAt: local.expiresAt) }
            return .trial(daysLeft: daysLeft, endsAt: endsAt)
        case .inGracePeriod:
            guard let graceEndsAt = local.gracePeriodExpiresAt ?? local.expiresAt, graceEndsAt > now else { return nil }
            return .grace(expiresAt: graceEndsAt)
        case .inBillingRetry:
            guard let gracePeriodExpiresAt = local.gracePeriodExpiresAt, gracePeriodExpiresAt > now else { return nil }
            return .grace(expiresAt: gracePeriodExpiresAt)
        case .expired, .revoked:
            return nil
        }
    }

    public static func serverState(_ server: ServerEntitlement, now: Date) -> EntitlementState? {
        switch server.status {
        case .active:
            guard server.isActive(at: now) else { return nil }
            return .premium(source: .server, expiresAt: server.expiresAt)
        case .inGracePeriod, .inBillingRetry:
            guard let graceEndsAt = server.expiresAt, graceEndsAt > now else { return nil }
            return .grace(expiresAt: graceEndsAt)
        case .none, .expired, .revoked:
            return nil
        }
    }

    public static func mirroredState(_ space: MirroredEntitlement, now: Date) -> EntitlementState? {
        guard space.isPremium(at: now) else { return nil }
        guard space.status == .trial,
              let endsAt = space.expiresAt,
              let daysLeft = trialDaysLeft(endsAt: endsAt, now: now)
        else { return .premium(source: .space, expiresAt: space.expiresAt) }
        return .trial(daysLeft: daysLeft, endsAt: endsAt)
    }

    public static func trialDaysLeft(endsAt: Date?, now: Date) -> Int? {
        guard let endsAt, endsAt > now else { return nil }
        let days = (endsAt.timeIntervalSince(now) / 86_400).rounded(.up)
        return max(1, Int(days))
    }
}
