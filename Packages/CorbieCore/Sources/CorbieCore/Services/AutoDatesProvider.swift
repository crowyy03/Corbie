import Foundation

public enum AutoDateKind: String, Sendable, Codable, Equatable, CaseIterable {
    case anniversary
    case wedding
    case memberBirthday
    case personBirthday
}

public struct AutoDate: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let kind: AutoDateKind
    public let date: Date
    public let years: Int?
    public let name: String?
    public let ownerMemberId: UUID?
    public let personId: UUID?

    public init(
        id: String,
        kind: AutoDateKind,
        date: Date,
        years: Int? = nil,
        name: String? = nil,
        ownerMemberId: UUID? = nil,
        personId: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.date = date
        self.years = years
        self.name = name
        self.ownerMemberId = ownerMemberId
        self.personId = personId
    }
}

public struct AutoDatesProvider: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public static func identifier(kind: AutoDateKind, owner: UUID?) -> String {
        let suffix = owner?.uuidString ?? "space"
        return "auto." + kind.rawValue + "." + suffix
    }

    public func autoDates(
        space: SpaceDTO,
        members: [MemberDTO],
        people: [PersonDTO],
        now: Date
    ) -> [AutoDate] {
        var result: [AutoDate] = []
        if let togetherSince = space.togetherSince,
           let anniversary = nextAnniversary(of: togetherSince, after: now) {
            result.append(
                AutoDate(
                    id: AutoDatesProvider.identifier(kind: .anniversary, owner: space.id),
                    kind: .anniversary,
                    date: anniversary.date,
                    years: anniversary.years
                )
            )
        }
        if let weddingDate = space.weddingDate,
           let wedding = nextAnniversary(of: weddingDate, after: now) {
            result.append(
                AutoDate(
                    id: AutoDatesProvider.identifier(kind: .wedding, owner: space.id),
                    kind: .wedding,
                    date: wedding.date,
                    years: wedding.years
                )
            )
        }
        for member in members {
            guard let month = member.birthdayMonth,
                  let day = member.birthdayDay,
                  let date = nextYearlyDate(month: month, day: day, after: now) else { continue }
            result.append(
                AutoDate(
                    id: AutoDatesProvider.identifier(kind: .memberBirthday, owner: member.id),
                    kind: .memberBirthday,
                    date: date,
                    name: member.displayName,
                    ownerMemberId: member.id
                )
            )
        }
        for person in people {
            guard let month = person.birthdayMonth,
                  let day = person.birthdayDay,
                  let date = nextYearlyDate(month: month, day: day, after: now) else { continue }
            result.append(
                AutoDate(
                    id: AutoDatesProvider.identifier(kind: .personBirthday, owner: person.id),
                    kind: .personBirthday,
                    date: date,
                    name: person.name,
                    ownerMemberId: person.ownerMemberId,
                    personId: person.id
                )
            )
        }
        return result.sorted { lhs, rhs in
            lhs.date == rhs.date ? lhs.id < rhs.id : lhs.date < rhs.date
        }
    }

    public func upcoming(
        space: SpaceDTO,
        members: [MemberDTO],
        people: [PersonDTO],
        now: Date,
        within days: Int
    ) -> [AutoDate] {
        let all = autoDates(space: space, members: members, people: people, now: now)
        return all.filter { autoDate in
            guard let away = daysAway(from: now, to: autoDate.date) else { return false }
            return away >= 0 && away <= days
        }
    }

    public func daysAway(from now: Date, to date: Date) -> Int? {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day
    }

    public func nextYearlyDate(month: Int, day: Int, after now: Date) -> Date? {
        guard (1...12).contains(month), day >= 1 else { return nil }
        let today = calendar.startOfDay(for: now)
        let year = calendar.component(.year, from: today)
        for candidate in [year, year + 1] {
            guard let date = clampedDate(year: candidate, month: month, day: day) else { continue }
            if date >= today { return date }
        }
        return nil
    }

    public func nextAnniversary(of origin: Date, after now: Date) -> (date: Date, years: Int)? {
        let today = calendar.startOfDay(for: now)
        let originComponents = calendar.dateComponents([.year, .month, .day], from: origin)
        guard let originYear = originComponents.year,
              let month = originComponents.month,
              let day = originComponents.day else { return nil }
        let currentYear = calendar.component(.year, from: today)
        for candidate in [currentYear, currentYear + 1, currentYear + 2] {
            guard candidate - originYear >= 1, let date = clampedDate(year: candidate, month: month, day: day) else {
                continue
            }
            if date >= today {
                return (date, candidate - originYear)
            }
        }
        return nil
    }

    public func clampedDate(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return nil }
        components.day = min(max(day, range.lowerBound), range.upperBound - 1)
        guard let date = calendar.date(from: components) else { return nil }
        return calendar.startOfDay(for: date)
    }
}
