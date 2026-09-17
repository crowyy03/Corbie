import Foundation
import Testing
@testable import CorbieCore

@Suite struct DepartedMemberRuleTests {
    private let owner = UUID()
    private let partner = UUID()

    private func rows(_ ids: [UUID]) -> [MemberDTO] {
        ids.map { MemberDTO(id: $0, appleUserHash: $0 == owner ? "owner-hash" : "hash-\($0)") }
    }

    private var ownerParticipant: ShareParticipantSummary {
        ShareParticipantSummary(isOwner: true, acceptance: .accepted)
    }

    @Test func anAcceptedPartnerKeepsEveryMember() {
        let removed = DepartedMemberRule.memberIdsToRemove(
            ownerMemberId: owner,
            members: rows([owner, partner]),
            participants: [ownerParticipant, ShareParticipantSummary(isOwner: false, acceptance: .accepted)]
        )
        #expect(removed.isEmpty)
    }

    @Test func aShareWithOnlyTheOwnerDropsEveryOtherMember() {
        let removed = DepartedMemberRule.memberIdsToRemove(
            ownerMemberId: owner,
            members: rows([owner, partner]),
            participants: [ownerParticipant]
        )
        #expect(removed == [partner])
    }

    @Test func aPartnerWhoWasRemovedFromTheShareIsDropped() {
        let removed = DepartedMemberRule.memberIdsToRemove(
            ownerMemberId: owner,
            members: rows([partner, owner]),
            participants: [ownerParticipant, ShareParticipantSummary(isOwner: false, acceptance: .removed)]
        )
        #expect(removed == [partner])
    }

    @Test func aPendingOrUnknownParticipantMeansWait() {
        for acceptance in [ShareParticipantSummary.Acceptance.pending, .unknown] {
            let removed = DepartedMemberRule.memberIdsToRemove(
                ownerMemberId: owner,
                members: rows([owner, partner]),
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
            members: rows([owner]),
            participants: [ownerParticipant]
        )
        #expect(removed.isEmpty)
    }

    @Test func everyNonOwnerRowGoesOnce() {
        let ghost = UUID()
        let removed = DepartedMemberRule.memberIdsToRemove(
            ownerMemberId: owner,
            members: rows([partner, ghost, owner, partner]),
            participants: []
        )
        #expect(removed == [partner, ghost])
    }

    @Test func withoutTheOwnerRowInTheSpaceNothingIsRemoved() {
        let removed = DepartedMemberRule.memberIdsToRemove(
            ownerMemberId: owner,
            members: rows([partner]),
            participants: [ownerParticipant]
        )
        #expect(removed.isEmpty)
    }

    @Test func anotherRowOfTheOwnersAppleIdIsKept() {
        let olderOwnerRow = MemberDTO(id: UUID(), appleUserHash: "owner-hash")
        let removed = DepartedMemberRule.memberIdsToRemove(
            ownerMemberId: owner,
            members: [olderOwnerRow] + rows([owner, partner]),
            participants: [ownerParticipant]
        )
        #expect(removed == [partner])
    }
}
