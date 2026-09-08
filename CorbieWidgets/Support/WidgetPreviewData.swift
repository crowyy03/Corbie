#if DEBUG
import CorbieCore
import Foundation

enum WidgetPreviewData {
    private static let busyDays = 4

    static func provider(now: Date = Date()) async -> WidgetDataProvider {
        WidgetDataProvider(controller: await PersistenceController.previewSeeded(now: now))
    }

    static func freeSlotsProvider(now: Date = Date(), calendar: Calendar = .current) async -> WidgetDataProvider {
        let controller = PersistenceController.inMemory()
        do {
            let seed = try await PreviewSeed.seed(into: controller, now: now, calendar: calendar)
            try await shareBusyTimes(seed: seed, now: now, calendar: calendar)
            return WidgetDataProvider(controller: controller, calendar: calendar, viewerMemberId: seed.me.id)
        } catch {
            return await provider(now: now)
        }
    }

    static func question(viewerAnswered: Bool) -> QuestionSnapshot {
        QuestionSnapshot(
            text: "What made you laugh today",
            viewer: WidgetQuestionMember(
                name: "Ilya",
                colorKey: MemberColorSlot.creatorDefault.rawValue,
                hasAnswered: viewerAnswered
            ),
            partner: WidgetQuestionMember(
                name: "Sofia",
                colorKey: MemberColorSlot.partnerDefault.rawValue,
                hasAnswered: false
            ),
            isRevealed: false,
            isPremium: true
        )
    }

    private static func shareBusyTimes(seed: PreviewSeedResult, now: Date, calendar: Calendar) async throws {
        let repositories = seed.controller.repositories
        for member in [seed.me, seed.partner] {
            _ = try await repositories.members.setSharesBusyTimes(memberId: member.id, shares: true)
            _ = try await repositories.busyIntervals.replace(
                spaceId: seed.space.id,
                memberId: member.id,
                source: .device,
                intervals: workdays(from: now, calendar: calendar)
            )
        }
    }

    private static func workdays(from now: Date, calendar: Calendar) -> [BusyIntervalDraft] {
        (0 ..< busyDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let start = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day),
                  let end = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day)
            else { return nil }
            return BusyIntervalDraft(startAt: start, endAt: end)
        }
    }
}
#endif
