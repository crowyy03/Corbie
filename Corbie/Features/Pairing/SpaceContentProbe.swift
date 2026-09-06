import CorbieCore
import Foundation

struct SpaceContentProbe: Sendable {
    private let repositories: Repositories

    init(repositories: Repositories) {
        self.repositories = repositories
    }

    func holdsContent(spaceId: UUID) async -> Bool {
        do {
            let tasks = try await repositories.tasks.tasks(
                TaskQuery(spaceId: spaceId, done: .any, folder: .all, includeArchived: true)
            )
            if tasks.isEmpty == false { return true }
            if try await repositories.events.events(spaceId: spaceId).isEmpty == false { return true }
            let wishes = try await repositories.wishes.wishes(WishQuery(spaceId: spaceId, fulfilled: nil))
            if wishes.isEmpty == false { return true }
            let goals = try await repositories.goals.goals(spaceId: spaceId, statuses: GoalStatus.allCases)
            if goals.isEmpty == false { return true }
            let folders = try await repositories.tasks.folders(spaceId: spaceId)
            if folders.contains(where: { $0.isPinnedShopping == false }) { return true }
            if try await repositories.capsules.capsules(spaceId: spaceId).isEmpty == false { return true }
            if try await repositories.votes.votes(spaceId: spaceId).isEmpty == false { return true }
            if try await repositories.people.people(spaceId: spaceId).isEmpty == false { return true }
            return false
        } catch {
            return true
        }
    }
}
