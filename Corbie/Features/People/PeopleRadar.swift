import CorbieCore
import Foundation
import os

@MainActor
struct PeopleRadar {
    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "people-radar")

    let environment: AppEnvironment
    var calendar: Calendar = .current

    func refresh(people: [PersonDTO], now: Date = Date()) async -> [PeopleRadarSummary] {
        guard let space = environment.space, let member = environment.currentMember else { return [] }
        let service = RadarService(calendar: calendar)
        let input = RadarInput(
            space: space,
            members: [member, environment.partner].compactMap { $0 },
            people: people,
            partnerWishes: await partnerWishes(spaceId: space.id),
            viewerMemberId: member.id
        )
        let lines = service.lines(input, now: now)
        do {
            await environment.notifications.cancelAll(kind: .dateRadar)
            try await service.schedule(
                input,
                prefs: member.notificationPrefs,
                now: now,
                using: environment.notifications
            )
        } catch {
            PeopleRadar.log.error("radar notifications not scheduled: \(error.localizedDescription, privacy: .public)")
        }
        return lines.map(PeopleRadarSummary.init)
    }

    private func partnerWishes(spaceId: UUID) async -> [WishDTO] {
        guard let partner = environment.partner else { return [] }
        do {
            return try await environment.repositories.wishes.wishes(
                WishQuery(spaceId: spaceId, owner: .member(partner.id), fulfilled: nil)
            )
        } catch {
            PeopleRadar.log.error("partner wishes not loaded: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
