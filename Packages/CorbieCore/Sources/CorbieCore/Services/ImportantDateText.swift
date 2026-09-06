import Foundation

public enum ImportantDateText {
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
            guard let name = title, name.isEmpty == false else {
                return String(localized: "us.counters.to.birthday.plain", locale: locale)
            }
            return String(format: String(localized: "us.counters.to.birthday", locale: locale), locale: locale, name)
        case .customEvent:
            guard let name = title, name.isEmpty == false else {
                return String(localized: "us.counters.to.event.plain", locale: locale)
            }
            return String(format: String(localized: "us.counters.to.event", locale: locale), locale: locale, name)
        case nil:
            return String(localized: "us.counters.to.event.plain", locale: locale)
        }
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
}
