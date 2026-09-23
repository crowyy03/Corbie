import CorbieCore
import Foundation

@MainActor
struct WishActions {
    let environment: AppEnvironment

    func fulfil(_ wishId: UUID) async -> Bool {
        guard environment.premiumGate.require(.edit) else { return false }
        do {
            _ = try await environment.repositories.wishes.fulfil(wishId: wishId)
            environment.analytics.record(.wishFulfilled)
            return true
        } catch {
            environment.report(error)
            return false
        }
    }

    func delete(_ wishId: UUID) async -> Bool {
        guard environment.premiumGate.require(.edit) else { return false }
        do {
            try await environment.repositories.wishes.delete(id: wishId)
            return true
        } catch {
            environment.report(error)
            return false
        }
    }
}
