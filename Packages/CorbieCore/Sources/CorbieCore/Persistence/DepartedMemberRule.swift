import Foundation

public enum DepartedMemberRule {
    public static func memberIdsToRemove(
        ownerMemberId: UUID,
        memberIds: [UUID],
        participants: [ShareParticipantSummary]
    ) -> [UUID] {
        let others = participants.filter { $0.isOwner == false }
        guard others.allSatisfy({ $0.acceptance == .removed }) else { return [] }
        var seen: Set<UUID> = [ownerMemberId]
        return memberIds.filter { seen.insert($0).inserted }
    }
}
