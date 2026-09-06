import CorbieCore
import Foundation

struct PersonDateLine: Identifiable, Equatable {
    let id: String
    let title: String
    let dayText: String?
    let caption: String?
    let dateId: UUID?

    var isBirthday: Bool { dateId == nil }
}

enum PersonDates {
    static func lines(
        for person: PersonDTO,
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [PersonDateLine] {
        var result: [PersonDateLine] = []
        if person.hasBirthday {
            result.append(
                PersonDateLine(
                    id: "birthday",
                    title: String(localized: "people.detail.birthday", locale: locale),
                    dayText: PersonBirthday.text(
                        month: person.birthdayMonth,
                        day: person.birthdayDay,
                        year: person.birthdayYear,
                        locale: locale
                    ),
                    caption: caption(
                        month: person.birthdayMonth,
                        day: person.birthdayDay,
                        year: person.birthdayYear,
                        now: now,
                        calendar: calendar,
                        locale: locale
                    ),
                    dateId: nil
                )
            )
        }
        for date in person.dates {
            result.append(
                PersonDateLine(
                    id: date.id.uuidString,
                    title: date.title,
                    dayText: PersonBirthday.text(
                        month: date.month,
                        day: date.day,
                        year: date.year,
                        locale: locale
                    ),
                    caption: caption(
                        month: date.month,
                        day: date.day,
                        year: nil,
                        now: now,
                        calendar: calendar,
                        locale: locale
                    ),
                    dateId: date.id
                )
            )
        }
        return result
    }

    static func rowCaption(
        for person: PersonDTO,
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String? {
        let relation = person.relation?.trimmingCharacters(in: .whitespacesAndNewlines)
        let age = PersonBirthday.ageText(person, now: now, calendar: calendar, locale: locale)
        let birthday = PersonBirthday.text(person, locale: locale)
        let day = join(birthday, age, locale: locale)
        return join(relation?.isEmpty == false ? relation : nil, day, locale: locale)
    }

    private static func caption(
        month: Int?,
        day: Int?,
        year: Int?,
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> String? {
        guard let month, let day,
              let next = AutoDatesProvider(calendar: calendar)
                  .nextYearly(month: month, day: day, year: year, after: now) else { return nil }
        let relative = RelativeDateText(locale: locale, calendar: calendar).relativeDay(for: next.date, now: now)
        guard let years = next.years else { return relative }
        return join(relative, PersonDateText.age(turning: years, locale: locale), locale: locale)
    }

    private static func join(_ lhs: String?, _ rhs: String?, locale: Locale) -> String? {
        switch (lhs, rhs) {
        case let (.some(lhs), .some(rhs)):
            return String(localized: "people.row.caption", defaultValue: "\(lhs) \u{00B7} \(rhs)", locale: locale)
        case let (.some(lhs), .none):
            return lhs
        case let (.none, .some(rhs)):
            return rhs
        case (.none, .none):
            return nil
        }
    }
}
