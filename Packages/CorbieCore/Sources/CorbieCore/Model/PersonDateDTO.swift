import Foundation

public struct PersonDateDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var personId: UUID?
    public var title: String
    public var month: Int?
    public var day: Int?
    public var year: Int?
    public var remindersEnabled: Bool
    public var createdAt: Date?

    public init(
        id: UUID,
        personId: UUID? = nil,
        title: String = "",
        month: Int? = nil,
        day: Int? = nil,
        year: Int? = nil,
        remindersEnabled: Bool = true,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.personId = personId
        self.title = title
        self.month = month
        self.day = day
        self.year = year
        self.remindersEnabled = remindersEnabled
        self.createdAt = createdAt
    }

    public init(_ date: PersonDate) {
        self.init(
            id: date.id ?? UUID(),
            personId: date.person?.id,
            title: date.title ?? "",
            month: date.month?.intValue,
            day: date.day?.intValue,
            year: date.year?.intValue,
            remindersEnabled: date.remindersEnabled,
            createdAt: date.createdAt
        )
    }

    public var hasDate: Bool { month != nil && day != nil }

    public static func inCalendarOrder(_ lhs: PersonDateDTO, _ rhs: PersonDateDTO) -> Bool {
        let left = (lhs.month ?? 13, lhs.day ?? 32)
        let right = (rhs.month ?? 13, rhs.day ?? 32)
        if left != right { return left < right }
        if lhs.title != rhs.title { return lhs.title < rhs.title }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
