#if DEBUG
import CorbieCore
import Foundation

enum WidgetPreviewData {
    static func provider(now: Date = Date()) async -> WidgetDataProvider {
        let controller = PersistenceController.inMemory()
        guard let seed = try? await PreviewSeed.seed(into: controller, now: now) else {
            return WidgetDataProvider(controller: controller)
        }
        try? await shareBusyTimes(seed: seed, now: now)
        return WidgetDataProvider(controller: controller, viewerMemberId: seed.me.id)
    }

    private static func shareBusyTimes(seed: PreviewSeedResult, now: Date) async throws {
        let repositories = seed.controller.repositories
        _ = try await repositories.members.setSharesBusyTimes(memberId: seed.me.id, shares: true)
        _ = try await repositories.members.setSharesBusyTimes(memberId: seed.partner.id, shares: true)
        _ = try await repositories.busyIntervals.replace(
            spaceId: seed.space.id,
            memberId: seed.me.id,
            source: .device,
            intervals: [
                BusyIntervalDraft(startAt: now, endAt: now.addingTimeInterval(4 * 60 * 60)),
                BusyIntervalDraft(
                    startAt: now.addingTimeInterval(26 * 60 * 60),
                    endAt: now.addingTimeInterval(30 * 60 * 60)
                )
            ],
            at: now
        )
        _ = try await repositories.busyIntervals.replace(
            spaceId: seed.space.id,
            memberId: seed.partner.id,
            source: .device,
            intervals: [
                BusyIntervalDraft(
                    startAt: now.addingTimeInterval(28 * 60 * 60),
                    endAt: now.addingTimeInterval(32 * 60 * 60)
                )
            ],
            at: now
        )
    }
}
#endif
