import Foundation
import StoreKit

public enum StoreEnvironment: String, Sendable, Equatable, CaseIterable, Codable {
    case production = "Production"
    case sandbox = "Sandbox"
    case xcode = "Xcode"

    init?(_ environment: AppStore.Environment) {
        switch environment {
        case .production: self = .production
        case .sandbox: self = .sandbox
        case .xcode: self = .xcode
        default: return nil
        }
    }
}

public struct AppTransactionProof: Sendable, Equatable {
    public let environment: StoreEnvironment
    public let signedAppTransaction: String

    public init(environment: StoreEnvironment, signedAppTransaction: String) {
        self.environment = environment
        self.signedAppTransaction = signedAppTransaction
    }
}

public protocol AppTransactionProviding: Sendable {
    func appTransactionProof() async -> AppTransactionProof?
}

public actor StoreKitAppTransaction: AppTransactionProviding {
    private var verified: AppTransactionProof?

    public init() {}

    public func appTransactionProof() async -> AppTransactionProof? {
        if let verified { return verified }
        guard let result = try? await AppTransaction.shared,
              case let .verified(transaction) = result,
              let environment = StoreEnvironment(transaction.environment)
        else { return nil }
        let proof = AppTransactionProof(environment: environment, signedAppTransaction: result.jwsRepresentation)
        verified = proof
        return proof
    }
}

public enum StoreEnvironmentRule {
    public static func readable(_ proof: AppTransactionProof?) -> StoreEnvironment {
        proof?.environment ?? .production
    }

    public static func mayWriteMirror(_ proof: AppTransactionProof?) -> Bool {
        proof?.environment == .production
    }
}
