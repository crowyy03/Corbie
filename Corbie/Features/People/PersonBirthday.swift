import CorbieCore
import Foundation

enum PersonBirthday {
    static let referenceYear = 2024

    static func calendar(locale: Locale) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        return calendar
    }

    static func date(month: Int, day: Int, locale: Locale = .current) -> Date? {
        let calendar = calendar(locale: locale)
        guard (1...12).contains(month), day >= 1 else { return nil }
        var components = DateComponents()
        components.year = referenceYear
        components.month = month
        components.day = 1
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth),
              range.contains(day) else { return nil }
        components.day = day
        return calendar.date(from: components)
    }

    static func text(month: Int?, day: Int?, locale: Locale = .current) -> String? {
        guard let month, let day, let date = date(month: month, day: day, locale: locale) else { return nil }
        let calendar = calendar(locale: locale)
        let style = Date.FormatStyle(
            date: .omitted,
            time: .omitted,
            locale: locale,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        .month(.abbreviated)
        .day()
        return style.format(date)
    }

    static func text(_ person: PersonDTO, locale: Locale = .current) -> String? {
        text(month: person.birthdayMonth, day: person.birthdayDay, locale: locale)
    }

    static func monthName(_ month: Int, locale: Locale = .current) -> String {
        let calendar = calendar(locale: locale)
        guard let date = date(month: month, day: 1, locale: locale) else { return month.formatted(.number) }
        let style = Date.FormatStyle(
            date: .omitted,
            time: .omitted,
            locale: locale,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        .month(.wide)
        return style.format(date)
    }

    static func dayCount(month: Int, locale: Locale = .current) -> Int {
        let calendar = calendar(locale: locale)
        guard let firstOfMonth = date(month: month, day: 1, locale: locale),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return 31 }
        return range.count
    }

    static func clampDay(_ day: Int, month: Int, locale: Locale = .current) -> Int {
        min(max(day, 1), dayCount(month: month, locale: locale))
    }
}
