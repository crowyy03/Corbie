import Foundation

public enum CorbieEventBusy {
    public static let busyKinds: Set<EventKind> = [.event, .trip]

    public static func intervals(from events: [EventDTO], calendar: Calendar = .current) -> [DateInterval] {
        BusyIntervals.merged(events.compactMap { interval(of: $0, calendar: calendar) })
    }

    private static func interval(of event: EventDTO, calendar: Calendar) -> DateInterval? {
        guard busyKinds.contains(event.kind), let start = event.startAt else { return nil }
        guard event.isAllDay == false else {
            return wholeDays(from: start, through: event.endAt ?? start, calendar: calendar)
        }
        guard let end = event.endAt, end > start else { return nil }
        return DateInterval(start: start, end: end)
    }

    private static func wholeDays(from start: Date, through end: Date, calendar: Calendar) -> DateInterval? {
        let firstDay = calendar.startOfDay(for: start)
        guard let dayAfterFirst = calendar.date(byAdding: .day, value: 1, to: firstDay) else { return nil }
        guard end > dayAfterFirst else { return DateInterval(start: firstDay, end: dayAfterFirst) }
        let lastDay = calendar.startOfDay(for: end)
        guard let coveredEnd = lastDay == end ? end : calendar.date(byAdding: .day, value: 1, to: lastDay) else {
            return nil
        }
        return DateInterval(start: firstDay, end: coveredEnd)
    }
}
