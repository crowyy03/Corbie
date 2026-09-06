import Foundation

public struct UsBadgeInput: Sendable, Equatable {
    public var space: SpaceDTO
    public var viewer: MemberDTO
    public var partner: MemberDTO?
    public var people: [PersonDTO]
    public var capsules: [CapsuleDTO]
    public var votes: [VoteDTO]
    public var wishes: [WishDTO]

    public init(
        space: SpaceDTO,
        viewer: MemberDTO,
        partner: MemberDTO? = nil,
        people: [PersonDTO] = [],
        capsules: [CapsuleDTO] = [],
        votes: [VoteDTO] = [],
        wishes: [WishDTO] = []
    ) {
        self.space = space
        self.viewer = viewer
        self.partner = partner
        self.people = people
        self.capsules = capsules
        self.votes = votes
        self.wishes = wishes
    }
}

public struct UsBadgeRule: Sendable {
    private let radar: RadarService

    public init(calendar: Calendar = .current) {
        radar = RadarService(calendar: calendar)
    }

    public func showsDot(_ input: UsBadgeInput, now: Date = Date()) -> Bool {
        hasCapsuleToOpen(input, now: now)
            || hasUnansweredVote(input)
            || hasWishFromPartner(input)
            || hasGiftToPick(input, now: now)
    }

    private func hasCapsuleToOpen(_ input: UsBadgeInput, now: Date) -> Bool {
        input.capsules.contains { capsule in
            capsule.isUnlocked(at: now) && capsule.openedByMemberIds.contains(input.viewer.id) == false
        }
    }

    private func hasUnansweredVote(_ input: UsBadgeInput) -> Bool {
        input.votes.contains { $0.responses.hasAnswered(input.viewer.id) == false }
    }

    private func hasWishFromPartner(_ input: UsBadgeInput) -> Bool {
        guard let partner = input.partner else { return false }
        let since = input.viewer.lastUsVisitAt ?? .distantPast
        return input.wishes.contains { wish in
            wish.addedByMemberId == partner.id && (wish.createdAt ?? .distantPast) > since
        }
    }

    private func hasGiftToPick(_ input: UsBadgeInput, now: Date) -> Bool {
        let radarInput = RadarInput(
            space: input.space,
            members: [input.viewer, input.partner].compactMap { $0 },
            people: input.people,
            partnerWishes: partnerWishes(input),
            viewerMemberId: input.viewer.id
        )
        return radar.lines(radarInput, now: now).contains { $0.status.giftPicked == false }
    }

    private func partnerWishes(_ input: UsBadgeInput) -> [WishDTO] {
        guard let partner = input.partner else { return [] }
        return input.wishes.filter { $0.ownerMemberId == partner.id }
    }
}
