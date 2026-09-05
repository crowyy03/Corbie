import Foundation

public struct ImportedCalendar: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let sourceTitle: String?
    public let allowsModification: Bool

    public init(id: String, title: String, sourceTitle: String? = nil, allowsModification: Bool = true) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
        self.allowsModification = allowsModification
    }
}

public struct ImportedEvent: Sendable, Equatable, Identifiable {
    public let id: String
    public let calendarId: String
    public let title: String
    public let startAt: Date
    public let endAt: Date?
    public let isAllDay: Bool
    public let locationName: String?
    public let note: String?

    public init(
        id: String,
        calendarId: String,
        title: String,
        startAt: Date,
        endAt: Date? = nil,
        isAllDay: Bool = false,
        locationName: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.calendarId = calendarId
        self.title = title
        self.startAt = startAt
        self.endAt = endAt
        self.isAllDay = isAllDay
        self.locationName = locationName
        self.note = note
    }
}

public protocol EventStoreClient: Sendable {
    func requestAccess() async throws -> Bool
    func calendars() async throws -> [ImportedCalendar]
    func events(calendarIds: [String], from: Date, to: Date) async throws -> [ImportedEvent]
}

public struct CalendarImport: Sendable {
    public static let horizonMonths = 12

    private let client: any EventStoreClient
    private let calendar: Calendar

    public init(client: any EventStoreClient, calendar: Calendar = .current) {
        self.client = client
        self.calendar = calendar
    }

    public func requestAccess() async throws -> Bool {
        try await client.requestAccess()
    }

    public func calendars() async throws -> [ImportedCalendar] {
        try await client.calendars()
    }

    public func drafts(
        calendarIds: [String],
        spaceId: UUID,
        createdByMemberId: UUID?,
        existing: [EventDTO],
        now: Date = Date()
    ) async throws -> [EventDraft] {
        guard let horizon = calendar.date(
            byAdding: .month,
            value: CalendarImport.horizonMonths,
            to: now
        ) else {
            throw CorbieError.invalidInput("cannot compute the import horizon")
        }
        let imported = try await client.events(
            calendarIds: calendarIds,
            from: calendar.startOfDay(for: now),
            to: horizon
        )
        return CalendarImport.drafts(
            from: imported,
            existing: existing,
            spaceId: spaceId,
            createdByMemberId: createdByMemberId
        )
    }

    public static func drafts(
        from imported: [ImportedEvent],
        existing: [EventDTO],
        spaceId: UUID,
        createdByMemberId: UUID?
    ) -> [EventDraft] {
        var seen = Set(existing.compactMap(dedupeKey))
        var result: [EventDraft] = []
        for event in imported.sorted(by: { $0.startAt < $1.startAt }) {
            let key = dedupeKey(title: event.title, startAt: event.startAt)
            guard key.isEmpty == false, seen.contains(key) == false else { continue }
            seen.insert(key)
            result.append(
                EventDraft(
                    spaceId: spaceId,
                    title: event.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    startAt: event.startAt,
                    endAt: event.endAt,
                    isAllDay: event.isAllDay,
                    kind: .event,
                    locationName: event.locationName,
                    note: event.note,
                    createdByMemberId: createdByMemberId
                )
            )
        }
        return result
    }

    public static func dedupeKey(title: String, startAt: Date) -> String {
        let normalized = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard normalized.isEmpty == false else { return "" }
        return normalized + "|" + String(Int(startAt.timeIntervalSince1970.rounded()))
    }

    public static func dedupeKey(_ event: EventDTO) -> String? {
        guard let startAt = event.startAt else { return nil }
        let key = dedupeKey(title: event.title, startAt: startAt)
        return key.isEmpty ? nil : key
    }
}

#if canImport(EventKit)
import EventKit

public actor SystemEventStoreClient: EventStoreClient {
    private let store = EKEventStore()

    public init() { }

    public func requestAccess() async throws -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            throw CorbieError.auth(error.localizedDescription)
        }
    }

    public func calendars() async throws -> [ImportedCalendar] {
        store.calendars(for: .event).map { calendar in
            ImportedCalendar(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                sourceTitle: calendar.source?.title,
                allowsModification: calendar.allowsContentModifications
            )
        }
    }

    public func events(calendarIds: [String], from: Date, to: Date) async throws -> [ImportedEvent] {
        let selected = store.calendars(for: .event).filter { calendarIds.contains($0.calendarIdentifier) }
        guard selected.isEmpty == false else { return [] }
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: selected)
        return store.events(matching: predicate).compactMap { event in
            guard let startDate = event.startDate, let title = event.title else { return nil }
            return ImportedEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                calendarId: event.calendar?.calendarIdentifier ?? "",
                title: title,
                startAt: startDate,
                endAt: event.endDate,
                isAllDay: event.isAllDay,
                locationName: event.location,
                note: event.notes
            )
        }
    }
}
#endif
