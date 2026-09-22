import CorbieCore
import Foundation

struct PartnerChangeWatcher: Sendable {
    @MainActor
    func observe(_ environment: AppEnvironment) async {
        let changes = environment.repositories.changes.stream()
        await check(environment)
        for await _ in changes {
            await check(environment)
        }
    }

    @MainActor
    func check(_ environment: AppEnvironment) async {
        await environment.refreshSessionFromStore()
    }
}
