import Foundation
import os

public struct UnsupportedCurrencyRepair: Sendable {
    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "currency")

    private let repositories: Repositories

    public init(repositories: Repositories) {
        self.repositories = repositories
    }

    @discardableResult
    public func run(spaceId: UUID) async throws -> Int {
        do {
            let replaced = try await repositories.spaces.replaceUnsupportedDisplayCurrency(spaceId: spaceId)
                + repositories.plans.replaceUnsupportedCurrencies(spaceId: spaceId)
                + repositories.wishes.replaceUnsupportedCurrencies(spaceId: spaceId)
                + repositories.people.replaceUnsupportedGiftIdeaCurrencies(spaceId: spaceId)
            if replaced > 0 {
                UnsupportedCurrencyRepair.log.notice(
                    "replaced \(replaced, privacy: .public) unsupported currency codes with \(SupportedCurrencies.defaultCode, privacy: .public)"
                )
            }
            return replaced
        } catch {
            UnsupportedCurrencyRepair.log.error(
                "currency repair failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }
}
