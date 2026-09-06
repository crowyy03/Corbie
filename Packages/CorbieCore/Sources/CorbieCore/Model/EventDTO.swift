import Foundation

public struct EventDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var spaceId: UUID?
    public var title: String
    public var startAt: Date?
    public var endAt: Date?
    public var isAllDay: Bool
    public var kind: EventKind
    public var personId: UUID?
    public var locationName: String?
    public var address: String?
    public var latitude: Double?
    public var longitude: Double?
    public var note: String?
    public var reminderOffsets: [ReminderOffset]
    public var createdByMemberId: UUID?
    public var createdAt: Date?
    public var commentCount: Int

    public init(
        id: UUID,
        spaceId: UUID? = nil,
        title: String = "",
        startAt: Date? = nil,
        endAt: Date? = nil,
        isAllDay: Bool = false,
        kind: EventKind = .event,
        personId: UUID? = nil,
        locationName: String? = nil,
        address: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        note: String? = nil,
        reminderOffsets: [ReminderOffset] = [],
        createdByMemberId: UUID? = nil,
        createdAt: Date? = nil,
        commentCount: Int = 0
    ) {
        self.id = id
        self.spaceId = spaceId
        self.title = title
        self.startAt = startAt
        self.endAt = endAt
        self.isAllDay = isAllDay
        self.kind = kind
        self.personId = personId
        self.locationName = locationName
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
        self.reminderOffsets = reminderOffsets
        self.createdByMemberId = createdByMemberId
        self.createdAt = createdAt
        self.commentCount = commentCount
    }

    public init(_ event: Event) {
        self.init(
            id: event.id ?? UUID(),
            spaceId: event.space?.id,
            title: event.title ?? "",
            startAt: event.startAt,
            endAt: event.endAt,
            isAllDay: event.isAllDay,
            kind: event.kind,
            personId: event.personId,
            locationName: event.locationName,
            address: event.address,
            latitude: event.latitude?.doubleValue,
            longitude: event.longitude?.doubleValue,
            note: event.note,
            reminderOffsets: event.reminderOffsets,
            createdByMemberId: event.createdByMemberId,
            createdAt: event.createdAt,
            commentCount: event.comments.count
        )
    }

    public var hasLocation: Bool { latitude != nil && longitude != nil }
}
