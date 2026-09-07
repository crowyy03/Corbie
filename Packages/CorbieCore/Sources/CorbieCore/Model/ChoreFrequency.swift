import Foundation

public enum ChoreFrequency: String, Sendable, Equatable, CaseIterable, Codable {
    case daily
    case fewTimesAWeek
    case weekly
    case everyTwoWeeks
    case monthly
    case quarterly

    public static let midweekDays = [2, 4, 6]

    public var loadPerWeek: Double {
        switch self {
        case .daily: return 7
        case .fewTimesAWeek: return 3
        case .weekly: return 1
        case .everyTwoWeeks: return 0.5
        case .monthly: return 0.25
        case .quarterly: return 0.1
        }
    }

    public var recurrence: Recurrence {
        switch self {
        case .daily: return .daily
        case .fewTimesAWeek: return .weekdays(ChoreFrequency.midweekDays)
        case .weekly: return .weekly
        case .everyTwoWeeks: return .everyTwoWeeks
        case .monthly: return .monthly
        case .quarterly: return .quarterly
        }
    }
}
