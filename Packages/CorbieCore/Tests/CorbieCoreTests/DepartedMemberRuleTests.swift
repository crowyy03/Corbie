import Foundation
import Testing
@testable import CorbieCore

@Suite struct DepartedMemberRuleTests {
    private let owner = UUID()
    private let partner = UUID()

    private var ownerParticipant: ShareParticipantSummary {
        ShareParticipantSummary(isOwner: true, acceptance: .accepted)
    }

    @Test func anAcceptedPartnerKeepsEveryMember() {
        let removed = DepartedMemberRule.memberIdsToRemove(
            ownerMemberId: owner,
            memberIds: [owner, partner],
            participants: [ownerParticipant, ShareParticipantSummary(isOwner: false, acceptance: .accepted)]
        )
        #expect(removed.isEmpty)
    }

    @Test func aShareWithOnlyTheOwnerDropsEveryOtherMember() {
        let removed = DepartedMemberRule.memberIdsToRemove(
            ownerMemberId: owner,
            memberIds: [owner, partner],
            participants: [ownerParticipant]
        )
        #expect(removed == [partner])
    }

    @Test func aPartnerWhoWasRemovedFromTheShareIsDropped() {
        let removed = DepartedMemberRule.memberIdsToRemove(
            ownerMemberId: owner,
            memberIds: [partner, owner],
            participants: [ownerParticipant, ShareParticipantSummary(isOwner: false, acceptance: .removed)]
        )
        #expect(removed == [partner])
    }

    @Test func aPendingOrUnknownParticipantMeansWait() {
        for acceptance in [ShareParticipantSummary.Acceptance.pending, .unknown] {
            let removed = DepartedMemberRule.memberIdsToRemove(
                ownerMemberId: owner,
                memberIds: [owner, partner],
                participants: [
                    ownerParticipant,
                    ShareParticipantSummary(isOwner: false, acceptance: .removed),
                    ShareParticipantSummary(isOwner: false, acceptance: acceptance)
                ]
            )
            #expect(removed.isEmpty, "acceptance \(acceptance)")
        }
    }

    @Test func aSoloSpaceHasNothingToRemove() {
        let removed = DepartedMemberRule.memberIdsToRemove(
            ownerMemberId: owner,
            memberIds: [owner],
            participants: [ownerParticipant]
        )
        #expect(removed.isEmpty)
    }

    @Test func everyNonOwnerRowGoesOnceEvenWithoutTheOwnerRow() {
        let ghost = UUID()
        let removed = DepartedMemberRule.memberIdsToRemove(
            ownerMemberId: owner,
            memberIds: [partner, ghost, partner],
            participants: []
        )
        #expect(removed == [partner, ghost])
    }
}
