import Foundation

public struct DeviceCalendarEvent: Sendable, Equatable {
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let isFree: Bool
    public let isDeclined: Bool

    public init(start: Date, end: Date, isAllDay: Bool = false, isFree: Bool = false, isDeclined: Bool = false) {
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.isFree = isFree
        self.isDeclined = isDeclined
    }
}

public enum DeviceCalendarBusy {
    public static func intervals(from events: [DeviceCalendarEvent], calendar: Calendar = .current) -> [DateInterval] {
        events.compactMap { event in
            guard event.isFree == false, event.isDeclined == false else { return nil }
            guard event.isAllDay else {
                guard event.end > event.start else { return nil }
                return DateInterval(start: event.start, end: event.end)
            }
            return wholeDays(from: event.start, to: event.end, calendar: calendar)
        }
    }

    private static func wholeDays(from start: Date, to end: Date, calendar: Calendar) -> DateInterval? {
        let firstDay = calendar.startOfDay(for: start)
        let lastDay = calendar.startOfDay(for: end)
        let coveredEnd: Date
        if lastDay == end {
            coveredEnd = end
        } else if let next = calendar.date(byAdding: .day, value: 1, to: lastDay) {
            coveredEnd = next
        } else {
            return nil
        }
        guard coveredEnd > firstDay else { return nil }
        return DateInterval(start: firstDay, end: coveredEnd)
    }
}

public protocol DeviceCalendarSource: Sendable {
    func requestAccess() async throws -> Bool
    func busyRanges(from: Date, to: Date) async throws -> [DateInterval]
}

#if canImport(EventKit)
import EventKit

public actor SystemDeviceCalendarSource: DeviceCalendarSource {
    private let store = EKEventStore()
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func requestAccess() async throws -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            throw CorbieError.auth(error.localizedDescription)
        }
    }

    public func busyRanges(from: Date, to: Date) async throws -> [DateInterval] {
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: nil)
        let events = store.events(matching: predicate).compactMap { event -> DeviceCalendarEvent? in
            guard let start = event.startDate, let end = event.endDate else { return nil }
            return DeviceCalendarEvent(
                start: start,
                end: end,
                isAllDay: event.isAllDay,
                isFree: event.availability == .free,
                isDeclined: declinedByCurrentUser(event)
            )
        }
        return DeviceCalendarBusy.intervals(from: events, calendar: calendar)
    }

    private func declinedByCurrentUser(_ event: EKEvent) -> Bool {
        guard let attendees = event.attendees else { return false }
        return attendees.contains { $0.isCurrentUser && $0.participantStatus == .declined }
    }
}
#endif
