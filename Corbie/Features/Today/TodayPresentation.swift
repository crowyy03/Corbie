import CorbieCore
import Foundation

struct TodayPresentation {
    let locale: Locale
    let calendar: Calendar

    init(locale: Locale = .current, calendar: Calendar = .current) {
        self.locale = locale
        var configured = calendar
        configured.locale = locale
        self.calendar = configured
    }

    func headerDate(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return formatter.string(from: day)
    }

    func daysTogether(_ days: Int) -> String {
        days.formatted(.number.locale(locale))
    }

    func time(for entry: TodayEntry) -> String {
        guard entry.isAllDay == false, let startAt = entry.startAt else {
            return String(localized: "today.row.allday")
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter.string(from: startAt)
    }

    func fromPlan(_ title: String) -> String {
        String(format: String(localized: "today.row.fromplan"), locale: locale, title)
    }

    func dateTitle(_ date: UpcomingDate) -> String {
        WidgetDateLabel.upcoming(
            kind: date.kind,
            title: date.name,
            ordinal: date.ordinal,
            locale: locale
        )
    }

    func dateCaption(_ date: UpcomingDate) -> String {
        WidgetDateLabel.relativeDays(date.daysAway, locale: locale)
    }

    func giftLine(_ date: UpcomingDate) -> String {
        guard date.ideasCount > 0 else { return String(localized: "today.comingup.gift.none", locale: locale) }
        return String(localized: "today.comingup.gift \(date.ideasCount)", locale: locale)
    }

    func moreFreeTasks(_ count: Int) -> String {
        String(format: String(localized: "today.freetasks.more"), locale: locale, count)
    }

    func waitingWishes(partner: String, count: Int) -> (title: String, caption: String) {
        (
            String(format: String(localized: "today.waiting.wishes"), locale: locale, partner),
            String(format: String(localized: "today.waiting.wishes.count"), locale: locale, count)
        )
    }

    func checkboxLabel(_ entry: TodayEntry) -> String {
        let format = entry.isDone
            ? String(localized: "today.row.uncheck")
            : String(localized: "today.row.check")
        return String(format: format, locale: locale, entry.title)
    }
}
