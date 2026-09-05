import CorbieCore
import Foundation

enum CalendarEntrySource: Equatable {
    case event(EventDTO)
    case autoDate(AutoDate)
}

struct CalendarEntry: Identifiable, Equatable {
    let id: String
    let source: CalendarEntrySource
    let startAt: Date
    let startDay: Date
    let endDay: Date
    let isAllDay: Bool
    let kind: EventKind
    let ownerMemberId: UUID?

    init?(event: EventDTO, calendar: Calendar) {
        guard let startAt = event.startAt else { return nil }
        id = "event." + event.id.uuidString
        source = .event(event)
        self.startAt = startAt
        startDay = calendar.startOfDay(for: startAt)
        endDay = CalendarEntry.inclusiveEndDay(
            startAt: startAt,
            endAt: event.endAt,
            isAllDay: event.isAllDay,
            calendar: calendar
        )
        isAllDay = event.isAllDay
        kind = event.kind
        ownerMemberId = event.createdByMemberId
    }

    init(autoDate: AutoDate, calendar: Calendar) {
        let day = calendar.startOfDay(for: autoDate.date)
        id = "auto." + autoDate.id + "." + CalendarEntries.dayKey(day)
        source = .autoDate(autoDate)
        startAt = day
        startDay = day
        endDay = day
        isAllDay = true
        kind = autoDate.kind == .anniversary || autoDate.kind == .wedding ? .anniversary : .birthday
        ownerMemberId = autoDate.ownerMemberId
    }

    var event: EventDTO? {
        guard case let .event(event) = source else { return nil }
        return event
    }

    var autoDate: AutoDate? {
        guard case let .autoDate(autoDate) = source else { return nil }
        return autoDate
    }

    var eventId: UUID? { event?.id }

    var isStored: Bool { event != nil }

    var spansDays: Bool { endDay > startDay }

    var endAt: Date? { event?.endAt }

    func covers(_ day: Date, calendar: Calendar) -> Bool {
        let target = calendar.startOfDay(for: day)
        return target >= startDay && target <= endDay
    }

    static func inclusiveEndDay(startAt: Date, endAt: Date?, isAllDay: Bool, calendar: Calendar) -> Date {
        let first = calendar.startOfDay(for: startAt)
        guard let endAt, endAt > startAt else { return first }
        let last = calendar.startOfDay(for: endAt)
        guard isAllDay, last == endAt, last > first else { return max(first, last) }
        let inclusive = calendar.date(byAdding: .day, value: -1, to: last).map(calendar.startOfDay(for:))
        return max(first, inclusive ?? last)
    }
}

enum CalendarEntries {
    static func merge(events: [EventDTO], autoDates: [AutoDate], calendar: Calendar) -> [CalendarEntry] {
        let stored = events.compactMap { CalendarEntry(event: $0, calendar: calendar) }
        let taken = Set(stored.compactMap(coverageKey(for:)))
        let virtual = autoDates
            .filter { taken.contains(coverageKey(for: $0, calendar: calendar)) == false }
            .map { CalendarEntry(autoDate: $0, calendar: calendar) }
        return (stored + virtual).sorted(by: isOrderedBefore)
    }

    static func upcoming(_ entries: [CalendarEntry], from now: Date, calendar: Calendar, limit: Int) -> [CalendarEntry] {
        let today = calendar.startOfDay(for: now)
        return Array(entries.filter { $0.endDay >= today }.sorted(by: isOrderedBefore).prefix(limit))
    }

    static func entriesByDay(_ entries: [CalendarEntry], calendar: Calendar) -> [Date: [CalendarEntry]] {
        var result: [Date: [CalendarEntry]] = [:]
        for entry in entries where entry.spansDays == false {
            result[entry.startDay, default: []].append(entry)
        }
        return result.mapValues { $0.sorted(by: isOrderedBefore) }
    }

    static func isOrderedBefore(_ lhs: CalendarEntry, _ rhs: CalendarEntry) -> Bool {
        if lhs.startDay != rhs.startDay { return lhs.startDay < rhs.startDay }
        if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
        if lhs.startAt != rhs.startAt { return lhs.startAt < rhs.startAt }
        return lhs.id < rhs.id
    }

    private static func coverageKey(for entry: CalendarEntry) -> String? {
        guard let event = entry.event else { return nil }
        let day = dayKey(entry.startDay)
        switch event.kind {
        case .birthday:
            guard let personId = event.personId else { return "birthday.member." + day }
            return "birthday.person." + personId.uuidString + "." + day
        case .anniversary:
            return "anniversary." + day
        case .event, .trip:
            return nil
        }
    }

    private static func coverageKey(for autoDate: AutoDate, calendar: Calendar) -> String {
        let day = dayKey(calendar.startOfDay(for: autoDate.date))
        switch autoDate.kind {
        case .personBirthday:
            let personId = autoDate.personId?.uuidString ?? autoDate.id
            return "birthday.person." + personId + "." + day
        case .memberBirthday:
            return "birthday.member." + day
        case .anniversary, .wedding:
            return "anniversary." + day
        }
    }

    static func dayKey(_ day: Date) -> String {
        String(Int(day.timeIntervalSinceReferenceDate.rounded()))
    }
}
