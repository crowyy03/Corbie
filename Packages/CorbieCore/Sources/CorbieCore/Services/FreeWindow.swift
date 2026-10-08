import Foundation

public struct FreeWindow: Sendable, Equatable {
    public static let defaultDays = 3

    public let endsAt: Date

    public init(endsAt: Date) {
        self.endsAt = endsAt
    }

    public init?(spaceCreatedAt: Date?, days: Int, calendar: Calendar) {
        guard let spaceCreatedAt, days > 0,
              let lastMoment = calendar.date(byAdding: .day, value: days, to: spaceCreatedAt),
              let endsAt = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastMoment))
        else { return nil }
        self.endsAt = endsAt
    }

    public func isOpen(at moment: Date) -> Bool {
        moment < endsAt
    }

    public func daysAfterToday(at moment: Date, calendar: Calendar) -> Int {
        guard let lastDay = calendar.date(byAdding: .day, value: -1, to: endsAt) else { return 0 }
        let today = calendar.startOfDay(for: moment)
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: lastDay)).day ?? 0
        return max(days, 0)
    }
}
