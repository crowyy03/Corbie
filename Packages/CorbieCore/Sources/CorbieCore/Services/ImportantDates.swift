import Foundation

public enum ImportantDateKind: String, Sendable, Codable, Equatable, CaseIterable {
    case anniversary
    case wedding
    case partnerBirthday
    case customEvent
}

public struct ImportantDateLabel: Sendable, Codable, Equatable {
    public let kind: ImportantDateKind
    public let ordinal: Int?
    public let personName: String?

    public init(kind: ImportantDateKind, ordinal: Int? = nil, personName: String? = nil) {
        self.kind = kind
        self.ordinal = ordinal
        self.personName = personName
    }
}

public struct ImportantDate: Sendable, Equatable, Identifiable {
    public let id: String
    public let label: ImportantDateLabel
    public let date: Date
    public let daysAway: Int
    public let eventId: UUID?

    public init(id: String, label: ImportantDateLabel, date: Date, daysAway: Int, eventId: UUID? = nil) {
        self.id = id
        self.label = label
        self.date = date
        self.daysAway = daysAway
        self.eventId = eventId
    }

    public var kind: ImportantDateKind { label.kind }
    public var ordinal: Int? { label.ordinal }
    public var personName: String? { label.personName }
}

public enum ImportantDates {
    public static func daysTogether(space: SpaceDTO, now: Date, calendar: Calendar = .current) -> Int? {
        guard let togetherSince = space.togetherSince else { return nil }
        let from = calendar.startOfDay(for: togetherSince)
        let to = calendar.startOfDay(for: now)
        guard let days = calendar.dateComponents([.day], from: from, to: to).day else { return nil }
        return max(0, days)
    }

    public static func nextImportantDate(
        space: SpaceDTO,
        members: [MemberDTO],
        people: [PersonDTO],
        pinnedEvents: [EventDTO],
        now: Date,
        viewerMemberId: UUID? = nil,
        calendar: Calendar = .current
    ) -> ImportantDate? {
        upcomingImportantDates(
            space: space,
            members: members,
            people: people,
            pinnedEvents: pinnedEvents,
            now: now,
            viewerMemberId: viewerMemberId,
            calendar: calendar
        ).first
    }

    public static func upcomingImportantDates(
        space: SpaceDTO,
        members: [MemberDTO],
        people: [PersonDTO],
        pinnedEvents: [EventDTO],
        now: Date,
        viewerMemberId: UUID? = nil,
        calendar: Calendar = .current
    ) -> [ImportantDate] {
        let provider = AutoDatesProvider(calendar: calendar)
        let partners = members.filter { viewerMemberId == nil || $0.id != viewerMemberId }
        let autoDates = provider.autoDates(space: space, members: partners, people: [], now: now)
        var candidates: [ImportantDate] = autoDates.compactMap { autoDate in
            guard let kind = importantKind(for: autoDate.kind),
                  let daysAway = provider.daysAway(from: now, to: autoDate.date) else { return nil }
            return ImportantDate(
                id: autoDate.id,
                label: ImportantDateLabel(kind: kind, ordinal: autoDate.years, personName: autoDate.name),
                date: autoDate.date,
                daysAway: daysAway
            )
        }
        let today = calendar.startOfDay(for: now)
        for event in pinnedEvents {
            guard let startAt = event.startAt else { continue }
            let day = calendar.startOfDay(for: startAt)
            guard day >= today, let daysAway = calendar.dateComponents([.day], from: today, to: day).day else {
                continue
            }
            candidates.append(
                ImportantDate(
                    id: "event." + event.id.uuidString,
                    label: ImportantDateLabel(
                        kind: .customEvent,
                        ordinal: nil,
                        personName: personName(for: event, in: people) ?? event.title
                    ),
                    date: startAt,
                    daysAway: daysAway,
                    eventId: event.id
                )
            )
        }
        return candidates.sorted { lhs, rhs in
            lhs.date == rhs.date ? lhs.id < rhs.id : lhs.date < rhs.date
        }
    }

    private static func importantKind(for kind: AutoDateKind) -> ImportantDateKind? {
        switch kind {
        case .anniversary:
            return .anniversary
        case .wedding:
            return .wedding
        case .memberBirthday:
            return .partnerBirthday
        case .personBirthday:
            return nil
        }
    }

    private static func personName(for event: EventDTO, in people: [PersonDTO]) -> String? {
        guard event.kind == .birthday, let personId = event.personId else { return nil }
        return people.first { $0.id == personId }?.name
    }
}
