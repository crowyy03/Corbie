import Foundation

public enum WidgetDateLabel {
    public static func upcoming(
        kind: WidgetDateKind,
        title: String?,
        ordinal: Int? = nil,
        locale: Locale = .current
    ) -> String {
        switch kind {
        case .anniversary:
            guard let ordinal else {
                return String(localized: "widget.date.anniversary.plain", locale: locale)
            }
            return String(
                format: String(localized: "widget.date.anniversary", locale: locale),
                locale: locale,
                ImportantDateText.ordinalText(ordinal, locale: locale)
            )
        case .wedding:
            return String(localized: "widget.date.wedding", locale: locale)
        case .memberBirthday, .personBirthday:
            guard let name = nonEmpty(title) else {
                return String(localized: "widget.date.birthday.plain", locale: locale)
            }
            if let withAge = PersonDateText.birthdayTitle(person: name, ordinal: ordinal, locale: locale) {
                return withAge
            }
            return String(format: String(localized: "widget.date.birthday", locale: locale), locale: locale, name)
        case .event:
            guard let name = nonEmpty(title) else {
                return String(localized: "widget.date.event.plain", locale: locale)
            }
            return name
        }
    }

    public static func relativeDays(_ daysAway: Int, locale: Locale = .current) -> String {
        switch daysAway {
        case ..<0:
            return String(localized: "widget.date.past", locale: locale)
        case 0:
            return String(localized: "widget.date.today", locale: locale)
        case 1:
            return String(localized: "widget.date.tomorrow", locale: locale)
        default:
            return String(localized: "widget.date.in", defaultValue: "in \(daysAway) days", locale: locale)
        }
    }

    public static func shortDate(_ date: Date, now: Date, locale: Locale = .current, calendar: Calendar = .current) -> String {
        RelativeDateText(locale: locale, calendar: calendar).dueText(for: date, now: now)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else { return nil }
        return value
    }
}
