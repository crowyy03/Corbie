import Foundation

public enum WidgetDateLabel {
    public static func countdown(
        kind: ImportantDateKind?,
        ordinal: Int?,
        title: String?,
        locale: Locale = .current
    ) -> String {
        switch kind {
        case .anniversary:
            guard let ordinal else { return String(localized: "us.counters.to.anniversary.plain", locale: locale) }
            return String(
                format: String(localized: "us.counters.to.anniversary", locale: locale),
                locale: locale,
                ordinalText(ordinal, locale: locale)
            )
        case .wedding:
            return String(localized: "us.counters.to.wedding", locale: locale)
        case .partnerBirthday:
            guard let name = nonEmpty(title) else {
                return String(localized: "us.counters.to.birthday.plain", locale: locale)
            }
            return String(format: String(localized: "us.counters.to.birthday", locale: locale), locale: locale, name)
        case .customEvent:
            guard let name = nonEmpty(title) else {
                return String(localized: "us.counters.to.event.plain", locale: locale)
            }
            return String(format: String(localized: "us.counters.to.event", locale: locale), locale: locale, name)
        case nil:
            return String(localized: "us.counters.to.event.plain", locale: locale)
        }
    }

    public static func upcoming(_ date: WidgetDate, locale: Locale = .current) -> String {
        switch date.kind {
        case .anniversary:
            guard let ordinal = date.ordinal else {
                return String(localized: "widget.date.anniversary.plain", locale: locale)
            }
            return String(
                format: String(localized: "widget.date.anniversary", locale: locale),
                locale: locale,
                ordinalText(ordinal, locale: locale)
            )
        case .wedding:
            return String(localized: "widget.date.wedding", locale: locale)
        case .memberBirthday, .personBirthday:
            guard let name = nonEmpty(date.title) else {
                return String(localized: "widget.date.birthday.plain", locale: locale)
            }
            return String(format: String(localized: "widget.date.birthday", locale: locale), locale: locale, name)
        case .event:
            guard let title = nonEmpty(date.title) else {
                return String(localized: "widget.date.event.plain", locale: locale)
            }
            return title
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

    public static func ordinalText(_ value: Int, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .ordinal
        guard let text = formatter.string(from: NSNumber(value: value)) else {
            return value.formatted(.number.locale(locale))
        }
        return text
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else { return nil }
        return value
    }
}
