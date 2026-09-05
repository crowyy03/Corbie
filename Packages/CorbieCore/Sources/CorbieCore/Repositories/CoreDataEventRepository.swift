import CoreData
import Foundation

public struct CoreDataEventRepository: EventRepository {
    private let access: CoreDataAccess

    public init(stack: CoreDataStack) {
        access = CoreDataAccess(stack: stack)
    }

    public func create(_ draft: EventDraft) async throws -> EventDTO {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            throw CorbieError.invalidInput("event title is empty")
        }
        if let endAt = draft.endAt, endAt < draft.startAt {
            throw CorbieError.invalidInput("event ends before it starts")
        }
        return try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: draft.spaceId, in: context)
            let event = Event(context: context)
            context.assign(event, toStoreOf: space)
            event.space = space
            event.title = title
            event.startAt = draft.startAt
            event.endAt = draft.endAt
            event.isAllDay = draft.isAllDay
            event.kind = draft.kind
            event.personId = draft.personId
            event.locationName = draft.locationName
            event.address = draft.address
            event.latitude = draft.latitude.map(NSNumber.init(value:))
            event.longitude = draft.longitude.map(NSNumber.init(value:))
            event.note = draft.note
            event.reminderOffsets = draft.reminderOffsets
            event.createdByMemberId = draft.createdByMemberId
            return EventDTO(event)
        }
    }

    public func update(_ event: EventDTO) async throws -> EventDTO {
        try await access.write { context in
            let entity: Event = try ManagedFetch.require(Event.entityName, id: event.id, in: context)
            entity.title = event.title
            entity.startAt = event.startAt
            entity.endAt = event.endAt
            entity.isAllDay = event.isAllDay
            entity.kind = event.kind
            entity.personId = event.personId
            entity.locationName = event.locationName
            entity.address = event.address
            entity.latitude = event.latitude.map(NSNumber.init(value:))
            entity.longitude = event.longitude.map(NSNumber.init(value:))
            entity.note = event.note
            entity.reminderOffsets = event.reminderOffsets
            return EventDTO(entity)
        }
    }

    public func event(id: UUID) async throws -> EventDTO? {
        try await access.read { context in
            let event: Event? = try ManagedFetch.first(Event.entityName, id: id, in: context)
            return event.map(EventDTO.init)
        }
    }

    public func events(spaceId: UUID, from: Date?, to: Date?) async throws -> [EventDTO] {
        try await access.read { context in
            var predicates = [ManagedFetch.spaceRelation(spaceId)]
            if let to {
                predicates.append(NSPredicate(format: "startAt <= %@", to as NSDate))
            }
            if let from {
                predicates.append(
                    NSPredicate(
                        format: "endAt >= %@ OR (endAt == nil AND startAt >= %@)",
                        from as NSDate,
                        from as NSDate
                    )
                )
            }
            let events: [Event] = try ManagedFetch.all(
                Event.entityName,
                predicate: NSCompoundPredicate(andPredicateWithSubpredicates: predicates),
                sort: [NSSortDescriptor(key: "startAt", ascending: true)],
                in: context
            )
            return events.map(EventDTO.init)
        }
    }

    public func delete(id: UUID) async throws {
        try await access.write { context in
            guard let event: Event = try ManagedFetch.first(Event.entityName, id: id, in: context) else { return }
            context.delete(event)
        }
    }

    public func addComment(eventId: UUID, memberId: UUID?, text: String) async throws -> EventCommentDTO {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw CorbieError.invalidInput("comment is empty")
        }
        guard trimmed.count <= EventComment.maxLength else {
            throw CorbieError.invalidInput("comment is longer than \(EventComment.maxLength)")
        }
        return try await access.write { context in
            let event: Event = try ManagedFetch.require(Event.entityName, id: eventId, in: context)
            let comment = EventComment(context: context)
            context.assign(comment, toStoreOf: event)
            comment.event = event
            comment.memberId = memberId
            comment.text = trimmed
            return EventCommentDTO(comment)
        }
    }

    public func comments(eventId: UUID) async throws -> [EventCommentDTO] {
        try await access.read { context in
            let comments: [EventComment] = try ManagedFetch.all(
                EventComment.entityName,
                predicate: NSPredicate(format: "event.id == %@", eventId as NSUUID),
                sort: [NSSortDescriptor(key: "createdAt", ascending: true)],
                in: context
            )
            return comments.map(EventCommentDTO.init)
        }
    }

    public func deleteComment(id: UUID) async throws {
        try await access.write { context in
            let comment: EventComment? = try ManagedFetch.first(EventComment.entityName, id: id, in: context)
            guard let comment else { return }
            context.delete(comment)
        }
    }
}
