import Foundation

public enum WidgetGoalText {
    public static func steps(done: Int, total: Int, locale: Locale = .current) -> String {
        let doneText = done.formatted(.number.locale(locale))
        let totalText = total.formatted(.number.locale(locale))
        return String(
            localized: "goals.card.steps",
            defaultValue: "\(doneText)/\(totalText) steps",
            locale: locale
        )
    }
}
