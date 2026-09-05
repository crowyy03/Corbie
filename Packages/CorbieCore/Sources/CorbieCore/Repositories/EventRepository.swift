import Foundation

public struct EventDraft: Sendable, Equatable {
    public var spaceId: UUID
    public var title: String
    public var startAt: Date
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

    public init(
        spaceId: UUID,
        title: String,
        startAt: Date,
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
        createdByMemberId: UUID? = nil
    ) {
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
    }
}

public protocol EventRepository: Sendable {
    func create(_ draft: EventDraft) async throws -> EventDTO
    func update(_ event: EventDTO) async throws -> EventDTO
    func event(id: UUID) async throws -> EventDTO?
    func events(spaceId: UUID, from: Date?, to: Date?) async throws -> [EventDTO]
    func delete(id: UUID) async throws
    func addComment(eventId: UUID, memberId: UUID?, text: String) async throws -> EventCommentDTO
    func comments(eventId: UUID) async throws -> [EventCommentDTO]
    func deleteComment(id: UUID) async throws
}

extension EventRepository {
    public func events(spaceId: UUID) async throws -> [EventDTO] {
        try await events(spaceId: spaceId, from: nil, to: nil)
    }
}
