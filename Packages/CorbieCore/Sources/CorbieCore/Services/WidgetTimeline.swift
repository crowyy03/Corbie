import Foundation

public enum WidgetTimelineDates {
    public static let dayInterval: TimeInterval = 24 * 60 * 60

    public static func nextMidnight(after date: Date, calendar: Calendar = .current) -> Date {
        var candidate = calendar.startOfDay(for: date)
        for _ in 0 ..< 3 {
            guard let stepped = calendar.date(byAdding: .day, value: 1, to: candidate) else { break }
            candidate = calendar.startOfDay(for: stepped)
            if candidate > date { return candidate }
        }
        return date.addingTimeInterval(dayInterval)
    }

    public static func entryDates(now: Date, calendar: Calendar = .current) -> [Date] {
        [now, nextMidnight(after: now, calendar: calendar)]
    }
}
