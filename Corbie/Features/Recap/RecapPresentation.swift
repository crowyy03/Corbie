import CorbieCore
import Foundation

struct RecapPresentation {
    let locale: Locale
    let calendar: Calendar

    init(locale: Locale = .current, calendar: Calendar = .current) {
        self.locale = locale
        var configured = calendar
        configured.locale = locale
        self.calendar = configured
    }

    func goalLine(_ move: RecapGoalMove) -> String {
        String(
            format: String(localized: "recap.goal.line"),
            locale: locale,
            move.title,
            deltaText(move),
            percentText(move.progress)
        )
    }

    func deltaText(_ move: RecapGoalMove) -> String {
        let money = Money(amount: abs(move.delta), currency: move.currency).formatted(locale: locale)
        let format = move.delta < 0
            ? String(localized: "recap.goal.delta.down")
            : String(localized: "recap.goal.delta.up")
        return String(format: format, locale: locale, money)
    }

    func percentText(_ progress: Double) -> String {
        progress.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    func upcomingTitle(_ item: RecapUpcoming) -> String {
        WidgetDateLabel.upcoming(kind: WidgetDateKind(item.kind), title: item.name, locale: locale)
    }

    func upcomingCaption(_ item: RecapUpcoming, now: Date) -> String {
        WidgetDateLabel.shortDate(item.date, now: now, locale: locale, calendar: calendar)
    }

    func milestoneLine(_ milestone: RecapMilestone) -> String {
        String(format: String(localized: "recap.milestone"), locale: locale, milestone.days)
    }

    func count(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }
}
