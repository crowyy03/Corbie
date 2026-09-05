import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class CapsuleOpenViewModel {
    private(set) var capsule: CapsuleDTO
    private(set) var isBroken: Bool
    private(set) var isWorking = false

    @ObservationIgnored private var environment: AppEnvironment?

    init(capsule: CapsuleDTO, viewerMemberId: UUID? = nil) {
        self.capsule = capsule
        isBroken = viewerMemberId.map { capsule.openedByMemberIds.contains($0) } ?? false
    }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
        if let memberId = environment.currentMember?.id, capsule.openedByMemberIds.contains(memberId) {
            isBroken = true
        }
    }

    var authorName: String {
        environment?.memberName(id: capsule.authorMemberId) ?? String(localized: "member.name.partner")
    }

    var readByBothText: String {
        capsule.isReadByBoth
            ? String(localized: "capsules.row.readbyboth")
            : String(localized: "capsules.row.readbyyou")
    }

    func reveal() {
        isBroken = true
    }

    func markOpened() async -> CapsuleDTO? {
        guard let environment, let memberId = environment.currentMember?.id, isWorking == false else { return nil }
        guard capsule.openedByMemberIds.contains(memberId) == false else { return nil }
        isWorking = true
        defer { isWorking = false }
        do {
            let opened = try await environment.repositories.capsules.markOpened(
                capsuleId: capsule.id,
                memberId: memberId
            )
            capsule = opened
            environment.analytics.record(.capsuleOpened)
            await environment.notifications.cancelCapsuleOpen(capsuleId: opened.id)
            return opened
        } catch {
            environment.report(error)
            return nil
        }
    }
}
