import Foundation

public struct RevealReadDays: Sendable, Codable, Equatable {
    public static let limit = 366

    public let dayKeys: [String]

    public init(_ dayKeys: [String] = []) {
        self.dayKeys = Array(Set(dayKeys).sorted().suffix(RevealReadDays.limit))
    }

    public init(from decoder: any Decoder) throws {
        self.init(try decoder.singleValueContainer().decode([String].self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(dayKeys)
    }

    public func hasRead(_ dayKey: String, today todayKey: String) -> Bool {
        dayKeys.contains(dayKey) || dayKey < firstTrackedDay(today: todayKey)
    }

    public func adding(_ dayKey: String) -> RevealReadDays {
        guard dayKey >= firstTrackedDay(today: dayKey) else { return self }
        return RevealReadDays(dayKeys + [dayKey])
    }

    private func firstTrackedDay(today todayKey: String) -> String {
        dayKeys.first ?? todayKey
    }
}
