import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class UsHubViewModel {
    private(set) var counters: UsCounters = .empty
    private(set) var peopleCount = 0
    private(set) var capsuleCount = 0
    private(set) var voteCount = 0
    private(set) var isLoading = true

    @ObservationIgnored private var environment: AppEnvironment?

    func load(_ environment: AppEnvironment, now: Date = Date()) async {
        self.environment = environment
        defer { isLoading = false }
        guard let space = environment.space else {
            counters = .empty
            return
        }
        do {
            let repositories = environment.repositories
            let members = try await repositories.members.members(spaceId: space.id)
            let people = try await repositories.people.people(spaceId: space.id)
            let events = try await repositories.events.events(spaceId: space.id, from: now, to: nil)
            counters = UsCounters.make(
                space: space,
                members: members,
                people: people,
                events: events,
                viewerMemberId: environment.currentMember?.id,
                now: now
            )
            peopleCount = people.count
            capsuleCount = try await repositories.capsules.capsules(spaceId: space.id).count
            voteCount = try await repositories.votes.votes(spaceId: space.id).count
        } catch {
            environment.report(error)
        }
    }
}
