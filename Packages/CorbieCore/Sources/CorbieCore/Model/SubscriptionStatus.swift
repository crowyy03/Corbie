import Foundation

public enum SubscriptionStatus: String, Codable, Sendable, CaseIterable {
    case none
    case trial
    case active
    case expired
    case readonly
}
