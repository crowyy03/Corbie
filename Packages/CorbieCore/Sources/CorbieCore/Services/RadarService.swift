import Foundation

public struct RadarStatus: Sendable, Codable, Equatable {
    public let ideasCount: Int
    public let giftPicked: Bool

    public init(ideasCount: Int, giftPicked: Bool) {
        self.ideasCount = ideasCount
        self.giftPicked = giftPicked
    }
}

public struct RadarLine: Sendable, Equatable, Identifiable {
    public let autoDate: AutoDate
    public let daysAway: Int
    public let status: RadarStatus

    public init(autoDate: AutoDate, daysAway: Int, status: RadarStatus) {
        self.autoDate = autoDate
        self.daysAway = daysAway
        self.status = status
    }

    public var id: String { autoDate.id }
    public var date: Date { autoDate.date }
    public var name: String? { autoDate.name }
    public var kind: AutoDateKind { autoDate.kind }

    public var route: CorbieRoute {
        guard let personId = autoDate.personId else { return .us }
        return .person(personId)
    }
}

public struct RadarInput: Sendable {
    public var space: SpaceDTO
    public var members: [MemberDTO]
    public var people: [PersonDTO]
    public var partnerWishes: [WishDTO]
    public var viewerMemberId: UUID?

    public init(
        space: SpaceDTO,
        members: [MemberDTO] = [],
        people: [PersonDTO] = [],
        partnerWishes: [WishDTO] = [],
        viewerMemberId: UUID? = nil
    ) {
        self.space = space
        self.members = members
        self.people = people
        self.partnerWishes = partnerWishes
        self.viewerMemberId = viewerMemberId
    }
}

public struct RadarService: Sendable {
    public static let horizonDays = 14
    public static let schedulingHorizonDays = 365
    public static let recentGiftDays = 30

    public let calendar: Calendar
    private let provider: AutoDatesProvider

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
        provider = AutoDatesProvider(calendar: calendar)
    }

    public func lines(_ input: RadarInput, now: Date, within days: Int = RadarService.horizonDays) -> [RadarLine] {
        candidates(input, now: now, within: days).compactMap { autoDate in
            radarLine(for: autoDate, input: input, now: now)
        }
    }

    public func radarLine(for autoDate: AutoDate, input: RadarInput, now: Date) -> RadarLine? {
        guard let daysAway = provider.daysAway(from: now, to: autoDate.date) else { return nil }
        return RadarLine(
            autoDate: autoDate,
            daysAway: daysAway,
            status: status(for: autoDate, input: input, now: now)
        )
    }

    public func status(for autoDate: AutoDate, input: RadarInput, now: Date) -> RadarStatus {
        switch autoDate.kind {
        case .personBirthday:
            guard let person = input.people.first(where: { $0.id == autoDate.personId }) else {
                return RadarStatus(ideasCount: 0, giftPicked: false)
            }
            return RadarStatus(ideasCount: person.giftIdeaCount, giftPicked: person.hasPickedGift)
        case .memberBirthday, .anniversary, .wedding:
            return partnerStatus(input: input, now: now)
        }
    }

    @discardableResult
    public func schedule(
        _ input: RadarInput,
        prefs: NotificationPrefs,
        now: Date,
        using scheduler: NotificationScheduler
    ) async throws -> [CorbieNotificationRequest] {
        var scheduled: [CorbieNotificationRequest] = []
        for line in lines(input, now: now, within: RadarService.schedulingHorizonDays) {
            let request = try await scheduler.scheduleRadar(
                autoDateId: line.id,
                name: line.name,
                targetDate: line.date,
                ideasCount: line.status.ideasCount,
                giftPicked: line.status.giftPicked,
                route: line.route,
                prefs: prefs,
                now: now
            )
            if let request {
                scheduled.append(request)
            }
        }
        return scheduled
    }

    private func candidates(_ input: RadarInput, now: Date, within days: Int) -> [AutoDate] {
        let partners = input.members.filter { input.viewerMemberId == nil || $0.id != input.viewerMemberId }
        return provider
            .upcoming(
                space: input.space,
                members: partners,
                people: input.people,
                now: now,
                within: days
            )
            .filter { $0.kind != .wedding }
    }

    private func partnerStatus(input: RadarInput, now: Date) -> RadarStatus {
        let open = input.partnerWishes.filter { $0.isFulfilled == false }
        let threshold = calendar.date(byAdding: .day, value: -RadarService.recentGiftDays, to: now)
        let picked = input.partnerWishes.contains { wish in
            guard wish.isFulfilled, let fulfilledAt = wish.fulfilledAt, let threshold else { return false }
            return fulfilledAt >= threshold && fulfilledAt <= now
        }
        return RadarStatus(ideasCount: open.count, giftPicked: picked)
    }
}
