import Foundation

public enum CorbieEventBusy {
    public static let busyKinds: Set<EventKind> = [.event, .trip]

    public static func intervals(from events: [EventDTO], calendar: Calendar = .current) -> [DateInterval] {
        BusyIntervals.merged(events.compactMap { interval(of: $0, calendar: calendar) })
    }

    private static func interval(of event: EventDTO, calendar: Calendar) -> DateInterval? {
        guard busyKinds.contains(event.kind), let start = event.startAt else { return nil }
        guard event.isAllDay == false else {
            return BusyIntervals.wholeDays(from: start, through: event.endAt ?? start, calendar: calendar)
        }
        guard let end = event.endAt, end > start else { return nil }
        return DateInterval(start: start, end: end)
    }
}
