import Foundation
import Observation
import os

@Observable @MainActor
public final class UsBadgeProvider {
    public private(set) var showsDot = false

    @ObservationIgnored private let repositories: Repositories
    @ObservationIgnored private let rule: UsBadgeRule
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "us-badge")
    @ObservationIgnored private var viewed: Viewed?
    @ObservationIgnored private var reloads: Task<Void, Never>?

    private struct Viewed {
        var space: SpaceDTO
        var member: MemberDTO
        var partner: MemberDTO?
    }

    public init(
        repositories: Repositories,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repositories = repositories
        rule = UsBadgeRule(calendar: calendar)
        self.now = now
    }

    public func refresh(space: SpaceDTO?, viewer: MemberDTO?, partner: MemberDTO?) async {
        guard let space, let viewer else {
            viewed = nil
            showsDot = false
            return
        }
        viewed = Viewed(space: space, member: viewer, partner: partner)
        await recompute()
    }

    public func observeReloads(center: NotificationCenter = .default) {
        guard reloads == nil else { return }
        let reloaded = center.notifications(named: WidgetReloadRequest.notificationName).map { _ in () }
        reloads = Task { [weak self] in
            for await _ in reloaded {
                await self?.recompute()
            }
        }
    }

    @discardableResult
    public func markVisited(memberId: UUID) async throws -> MemberDTO {
        let member = try await repositories.members.markUsVisited(memberId: memberId, at: now())
        if viewed?.member.id == member.id {
            viewed?.member = member
        }
        await recompute()
        return member
    }

    private func recompute() async {
        guard let viewed else { return }
        do {
            let input = UsBadgeInput(
                space: viewed.space,
                viewer: viewed.member,
                partner: viewed.partner,
                people: try await repositories.people.people(spaceId: viewed.space.id),
                capsules: try await repositories.capsules.capsules(spaceId: viewed.space.id),
                votes: try await repositories.votes.votes(spaceId: viewed.space.id),
                wishes: try await repositories.wishes.wishes(
                    WishQuery(spaceId: viewed.space.id, owner: .any, fulfilled: nil)
                ),
                question: try await repositories.questions.storedQuestion(
                    spaceId: viewed.space.id,
                    viewerMemberId: viewed.member.id,
                    now: now()
                )
            )
            showsDot = rule.showsDot(input, now: now())
        } catch {
            log.error("the us badge was not recomputed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
