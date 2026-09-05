import CorbieCore
import Foundation
@testable import Corbie

enum CalendarTestSupport {
    static let timeZoneIdentifier = "Europe/Berlin"

    static func calendar(_ localeIdentifier: String) -> Calendar {
        let locale = Locale(identifier: localeIdentifier)
        var calendar = locale.calendar
        calendar.locale = locale
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .gmt
        return calendar
    }

    static func date(
        _ calendar: Calendar,
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0
    ) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: components) ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    static func event(
        _ calendar: Calendar,
        title: String,
        start: Date,
        end: Date? = nil,
        isAllDay: Bool = false,
        kind: EventKind = .event,
        personId: UUID? = nil,
        createdBy: UUID? = nil
    ) -> EventDTO {
        EventDTO(
            id: UUID(),
            title: title,
            startAt: start,
            endAt: end,
            isAllDay: isAllDay,
            kind: kind,
            personId: personId,
            createdByMemberId: createdBy
        )
    }

    static func autoDate(
        kind: AutoDateKind,
        date: Date,
        years: Int? = nil,
        name: String? = nil,
        ownerMemberId: UUID? = nil,
        personId: UUID? = nil
    ) -> AutoDate {
        AutoDate(
            id: AutoDatesProvider.identifier(kind: kind, owner: personId ?? ownerMemberId),
            kind: kind,
            date: date,
            years: years,
            name: name,
            ownerMemberId: ownerMemberId,
            personId: personId
        )
    }
}
