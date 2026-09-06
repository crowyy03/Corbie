import CorbieCore
import Foundation

struct UsCounters: Equatable {
    let daysTogether: Int?
    let next: ImportantDate?

    static let empty = UsCounters(daysTogether: nil, next: nil)

    static func make(
        space: SpaceDTO?,
        members: [MemberDTO],
        people: [PersonDTO],
        events: [EventDTO],
        viewerMemberId: UUID?,
        now: Date,
        calendar: Calendar = .current
    ) -> UsCounters {
        guard let space else { return .empty }
        let daysTogether = ImportantDates.daysTogether(space: space, now: now, calendar: calendar)
        let next = ImportantDates.nextImportantDate(
            space: space,
            members: members,
            people: people,
            pinnedEvents: events.filter { $0.kind == .anniversary },
            now: now,
            viewerMemberId: viewerMemberId,
            calendar: calendar
        )
        return UsCounters(daysTogether: daysTogether, next: next)
    }
}
