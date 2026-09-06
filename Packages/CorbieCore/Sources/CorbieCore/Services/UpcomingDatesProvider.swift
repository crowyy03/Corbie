import Foundation

public struct UpcomingDate: Sendable, Equatable, Identifiable {
    public static let radarHorizonDays = RadarService.horizonDays

    public let id: String
    public let kind: AutoDateKind
    public let name: String?
    public let date: Date
    public let daysAway: Int
    public let ordinal: Int?
    public let memberId: UUID?
    public let personId: UUID?
    public let eventId: UUID?
    public let radar: RadarStatus?

    public init(
        id: String,
        kind: AutoDateKind,
        name: String?,
        date: Date,
        daysAway: Int,
        ordinal: Int? = nil,
        memberId: UUID? = nil,
        personId: UUID? = nil,
        eventId: UUID? = nil,
        radar: RadarStatus? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.date = date
        self.daysAway = daysAway
        self.ordinal = ordinal
        self.memberId = memberId
        self.personId = personId
        self.eventId = eventId
        self.radar = radar
    }

    public var isGiftMissing: Bool {
        guard let radar, radar.giftPicked == false else { return false }
        guard daysAway <= UpcomingDate.radarHorizonDays else { return false }
        switch kind {
        case .anniversary, .wedding, .memberBirthday, .personBirthday:
            return true
        case .event:
            return false
        }
    }

    public var ideasCount: Int { radar?.ideasCount ?? 0 }
}

public struct UpcomingDatesProvider: Sendable {
    public static let horizonDays = 400

    private let repositories: Repositories
    private let calendar: Calendar

    public init(repositories: Repositories, calendar: Calendar = .current) {
        self.repositories = repositories
        self.calendar = calendar
    }

    public func dates(
        space: SpaceDTO,
        members: [MemberDTO],
        people: [PersonDTO],
        viewerMemberId: UUID?,
        now: Date,
        eventsFrom: Date
    ) async throws -> [UpcomingDate] {
        let partner = members.first { $0.id != viewerMemberId }
        let partnerWishes: [WishDTO]
        if let partner {
            partnerWishes = try await repositories.wishes.wishes(
                WishQuery(spaceId: space.id, owner: .member(partner.id), fulfilled: nil)
            )
        } else {
            partnerWishes = []
        }
        let radar = RadarService(calendar: calendar)
        let input = RadarInput(
            space: space,
            members: members,
            people: people,
            partnerWishes: partnerWishes,
            viewerMemberId: viewerMemberId
        )
        var result: [UpcomingDate] = AutoDatesProvider(calendar: calendar)
            .upcoming(
                space: space,
                members: members,
                people: people,
                now: now,
                within: UpcomingDatesProvider.horizonDays
            )
            .compactMap { autoDate in
                guard let daysAway = calendar.daysAway(from: now, to: autoDate.date) else { return nil }
                return UpcomingDate(
                    id: autoDate.id,
                    kind: autoDate.kind,
                    name: autoDate.name,
                    date: autoDate.date,
                    daysAway: daysAway,
                    ordinal: autoDate.years,
                    memberId: autoDate.ownerMemberId,
                    personId: autoDate.personId,
                    radar: daysAway <= RadarService.horizonDays
                        ? radar.radarLine(for: autoDate, input: input, now: now)?.status
                        : nil
                )
            }
        let horizon = calendar.date(byAdding: .day, value: UpcomingDatesProvider.horizonDays, to: now)
        let events = try await repositories.events.events(spaceId: space.id, from: eventsFrom, to: horizon)
        for event in events {
            guard let startAt = event.startAt,
                  startAt >= eventsFrom,
                  let daysAway = calendar.daysAway(from: now, to: startAt) else { continue }
            result.append(
                UpcomingDate(
                    id: "event." + event.id.uuidString,
                    kind: .event,
                    name: event.title,
                    date: startAt,
                    daysAway: daysAway,
                    memberId: event.createdByMemberId,
                    eventId: event.id
                )
            )
        }
        return result.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
    }
}
