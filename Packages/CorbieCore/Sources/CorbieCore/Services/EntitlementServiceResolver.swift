import Foundation

public enum EntitlementSource: String, Sendable, Equatable, CaseIterable, Codable {
    case trial
    case server
    case storeKit
}

public enum EntitlementState: Sendable, Equatable {
    case trial(daysLeft: Int)
    case active(source: EntitlementSource, expiresAt: Date?)
    case grace(expiresAt: Date?)
    case readOnly

    public var isPremium: Bool {
        switch self {
        case .trial, .active, .grace: return true
        case .readOnly: return false
        }
    }

    public var isReadOnly: Bool { isPremium == false }

    public var trialDaysLeft: Int? {
        guard case let .trial(daysLeft) = self else { return nil }
        return daysLeft
    }

    public var expiresAt: Date? {
        switch self {
        case let .active(_, expiresAt): return expiresAt
        case let .grace(expiresAt): return expiresAt
        case .trial, .readOnly: return nil
        }
    }
}

public struct ServerEntitlement: Sendable, Equatable, Codable {
    public let status: EntitlementStatus
    public let productId: String?
    public let expiresAt: Date?
    public let updatedAt: Date?

    public init(status: EntitlementStatus, productId: String? = nil, expiresAt: Date? = nil, updatedAt: Date? = nil) {
        self.status = status
        self.productId = productId
        self.expiresAt = expiresAt
        self.updatedAt = updatedAt
    }

    public init(payload: EntitlementPayload) {
        self.init(
            status: payload.status,
            productId: payload.productId,
            expiresAt: payload.expiresAt,
            updatedAt: payload.updatedAt
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
    public let expiresAt: Date?
    public let isRevoked: Bool

    public init(productId: String, expiresAt: Date? = nil, isRevoked: Bool = false) {
        self.productId = productId
        self.expiresAt = expiresAt
        self.isRevoked = isRevoked
    }

    public func isActive(at moment: Date) -> Bool {
        guard isRevoked == false else { return false }
        guard let expiresAt else { return true }
        return expiresAt > moment
    }
}

public protocol LocalEntitlementProviding: Sendable {
    func currentEntitlement() async -> LocalEntitlement?
}

public struct EntitlementInputs: Sendable, Equatable {
    public var trialEndsAt: Date?
    public var server: ServerEntitlement?
    public var local: LocalEntitlement?
    public var now: Date

    public init(
        trialEndsAt: Date? = nil,
        server: ServerEntitlement? = nil,
        local: LocalEntitlement? = nil,
        now: Date = Date()
    ) {
        self.trialEndsAt = trialEndsAt
        self.server = server
        self.local = local
        self.now = now
    }
}

public enum EntitlementResolver {
    public static func resolve(_ inputs: EntitlementInputs) -> EntitlementState {
        let now = inputs.now

        if inputs.server?.status == .revoked { return .readOnly }

        if let local = inputs.local, local.isActive(at: now) {
            return .active(source: .storeKit, expiresAt: local.expiresAt)
        }

        if let server = inputs.server {
            if server.isActive(at: now) {
                return .active(source: .server, expiresAt: server.expiresAt)
            }
            if server.status == .grace {
                return .grace(expiresAt: server.expiresAt)
            }
        }

        if let daysLeft = trialDaysLeft(endsAt: inputs.trialEndsAt, now: now) {
            return .trial(daysLeft: daysLeft)
        }

        return .readOnly
    }

    public static func trialDaysLeft(endsAt: Date?, now: Date) -> Int? {
        guard let endsAt, endsAt > now else { return nil }
        let days = (endsAt.timeIntervalSince(now) / 86_400).rounded(.up)
        return max(1, Int(days))
    }
}
