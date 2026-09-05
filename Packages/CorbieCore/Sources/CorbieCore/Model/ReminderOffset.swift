import Foundation

public enum ReminderOffset: Int, Codable, Sendable, CaseIterable {
    case dayBefore = 1
    case threeDaysBefore = 3
    case twoWeeksBefore = 14

    public var days: Int { rawValue }
}
