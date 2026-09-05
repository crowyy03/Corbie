import CorbieCore
import Foundation

enum UsCounterLabel: Equatable {
    case anniversary(years: Int?)
    case wedding
    case birthday(name: String?)
    case event(title: String?)

    var text: String {
        switch self {
        case let .anniversary(years):
            guard let years else { return String(localized: "us.counters.to.anniversary.plain") }
            return String(
                format: String(localized: "us.counters.to.anniversary"),
                UsCounters.ordinal(years)
            )
        case .wedding:
            return String(localized: "us.counters.to.wedding")
        case let .birthday(name):
            guard let name, name.isEmpty == false else {
                return String(localized: "us.counters.to.birthday.plain")
            }
            return String(format: String(localized: "us.counters.to.birthday"), name)
        case let .event(title):
            guard let title, title.isEmpty == false else {
                return String(localized: "us.counters.to.event.plain")
            }
            return String(format: String(localized: "us.counters.to.event"), title)
        }
    }
}

struct UsCounters: Equatable {
    struct NextDate: Equatable {
        let daysAway: Int
        let label: UsCounterLabel
    }

    let daysTogether: Int?
    let next: NextDate?

    static let empty = UsCounters(daysTogether: nil, next: nil)

    static func make(
        space: SpaceDTO?,
        members: [MemberDTO],
        people: [PersonDTO],
        events: [EventDTO],
        viewerMemberId: UUID?,
        now: Date,
        calendar: Calendar = .current
    ) -> UsCounters {
        guard let space else { return .empty }
        let daysTogether = ImportantDates.daysTogether(space: space, now: now, calendar: calendar)
        let next = ImportantDates.nextImportantDate(
            space: space,
            members: members,
            people: people,
            pinnedEvents: events.filter { $0.kind == .anniversary },
            now: now,
            viewerMemberId: viewerMemberId,
            calendar: calendar
        )
        guard let next else { return UsCounters(daysTogether: daysTogether, next: nil) }
        return UsCounters(
            daysTogether: daysTogether,
            next: NextDate(daysAway: next.daysAway, label: label(for: next))
        )
    }

    static func label(for date: ImportantDate) -> UsCounterLabel {
        switch date.kind {
        case .anniversary:
            return .anniversary(years: date.ordinal)
        case .wedding:
            return .wedding
        case .partnerBirthday:
            return .birthday(name: date.personName)
        case .customEvent:
            return .event(title: date.personName)
        }
    }

    static func ordinal(_ value: Int, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .ordinal
        guard let text = formatter.string(from: NSNumber(value: value)) else {
            return value.formatted(.number.locale(locale))
        }
        return text
    }
}
