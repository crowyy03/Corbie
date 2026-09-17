import Foundation

public enum DepartedMemberRule {
    public static func memberIdsToRemove(
        ownerMemberId: UUID,
        members: [MemberDTO],
        participants: [ShareParticipantSummary]
    ) -> [UUID] {
        let others = participants.filter { $0.isOwner == false }
        guard others.allSatisfy({ $0.acceptance == .removed }),
              let owner = members.first(where: { $0.id == ownerMemberId })
        else { return [] }
        var seen: Set<UUID> = [ownerMemberId]
        return members
            .filter { owner.appleUserHash == nil || $0.appleUserHash != owner.appleUserHash }
            .map(\.id)
            .filter { seen.insert($0).inserted }
    }
}
