import Foundation

public enum PersonDateText {
    public static func label(person: String, title: String, locale: Locale = .current) -> String {
        let name = person.trimmingCharacters(in: .whitespacesAndNewlines)
        let what = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else { return what }
        guard what.isEmpty == false else { return name }
        return String(localized: "people.date.label", defaultValue: "\(name): \(what)", locale: locale)
    }

    public static func birthdayTitle(person: String?, ordinal: Int?, locale: Locale = .current) -> String? {
        guard let person, person.isEmpty == false, let ordinal, ordinal > 0 else { return nil }
        let years = ImportantDateText.ordinalText(ordinal, locale: locale)
        return String(
            localized: "people.date.birthday.ordinal",
            defaultValue: "\(person)'s \(years) birthday",
            locale: locale
        )
    }

    public static func age(turning years: Int, locale: Locale = .current) -> String {
        String(localized: "people.age.turns", defaultValue: "turns \(years)", locale: locale)
    }
}
