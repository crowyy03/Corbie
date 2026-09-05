import Foundation

public enum Recurrence: Sendable, Equatable, Hashable {
    case none
    case daily
    case weekly
    case monthly
    case weekdays([Int])

    public static let weekdaysPrefix = "weekdays:"
}

extension Recurrence: RawRepresentable {
    public init?(rawValue: String) {
        switch rawValue {
        case "none":
            self = .none
        case "daily":
            self = .daily
        case "weekly":
            self = .weekly
        case "monthly":
            self = .monthly
        default:
            guard rawValue.hasPrefix(Recurrence.weekdaysPrefix) else { return nil }
            let list = rawValue.dropFirst(Recurrence.weekdaysPrefix.count)
            let days = list
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                .filter { (1...7).contains($0) }
            self = .weekdays(Array(Set(days)).sorted())
        }
    }

    public var rawValue: String {
        switch self {
        case .none:
            return "none"
        case .daily:
            return "daily"
        case .weekly:
            return "weekly"
        case .monthly:
            return "monthly"
        case let .weekdays(days):
            let sorted = Array(Set(days)).sorted()
            return Recurrence.weekdaysPrefix + sorted.map(String.init).joined(separator: ",")
        }
    }
}

extension Recurrence: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Recurrence(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "unknown recurrence \(raw)")
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension Recurrence {
    public var repeats: Bool {
        switch self {
        case .none:
            return false
        case let .weekdays(days):
            return days.isEmpty == false
        default:
            return true
        }
    }

    public func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .none:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case let .weekdays(days):
            let wanted = Set(days.filter { (1...7).contains($0) })
            guard wanted.isEmpty == false else { return nil }
            for offset in 1...7 {
                guard let candidate = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
                if wanted.contains(calendar.component(.weekday, from: candidate)) {
                    return candidate
                }
            }
            return nil
        }
    }
}
