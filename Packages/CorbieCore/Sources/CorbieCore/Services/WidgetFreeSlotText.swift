import Foundation

public struct WidgetFreeSlotText: Sendable {
    private let calendar: Calendar
    private let locale: Locale
    private let workingHours: WorkingHours

    public init(
        locale: Locale = .current,
        calendar: Calendar = .current,
        workingHours: WorkingHours = .standard
    ) {
        var configured = calendar
        configured.locale = locale
        self.calendar = configured
        self.locale = locale
        self.workingHours = workingHours
    }

    public func slot(_ slot: FreeSlot) -> WidgetFreeSlot {
        WidgetFreeSlot(start: slot.start, dayText: day(slot.start), windowText: window(slot))
    }

    public func day(_ date: Date) -> String {
        date.formatted(dateStyle.weekday(.abbreviated).day().month(.abbreviated))
    }

    public func window(_ slot: FreeSlot) -> String {
        if slot.isAllDay {
            return String(localized: "freetime.slot.allday", defaultValue: "all day", locale: locale)
        }
        if runsToTheEndOfTheDay(slot) {
            let start = time(slot.start)
            return String(localized: "freetime.slot.after", defaultValue: "after \(start)", locale: locale)
        }
        return time(slot.start) + " - " + time(slot.end)
    }

    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }

    private func runsToTheEndOfTheDay(_ slot: FreeSlot) -> Bool {
        guard let close = calendar.date(
            bySettingHour: workingHours.endHour,
            minute: 0,
            second: 0,
            of: slot.start
        ) else { return false }
        return slot.end >= close
    }

    private func time(_ date: Date) -> String {
        date.formatted(dateStyle.hour().minute())
    }
}
