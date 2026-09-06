import CorbieCore
import Foundation

struct FreeTimeRowText {
    private let calendar: Calendar
    private let locale: Locale
    private let workingHours: WorkingHours
    private let formatting: CalendarFormatting

    init(locale: Locale = .current, calendar: Calendar = .current, workingHours: WorkingHours = .standard) {
        var configured = calendar
        configured.locale = locale
        self.calendar = configured
        self.locale = locale
        self.workingHours = workingHours
        formatting = CalendarFormatting(locale: locale, calendar: configured)
    }

    func title(for slot: FreeSlot) -> String {
        formatting.shortDate(slot.start) + " · " + window(for: slot)
    }

    func duration(for slot: FreeSlot) -> String {
        Duration.seconds(slot.duration)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(locale))
    }

    func partnerTime(for slot: FreeSlot, partnerName: String) -> String? {
        guard let partnerLabel = slot.partnerLabel else { return nil }
        return String.localizedStringWithFormat(
            String(localized: "freetime.slot.partnertime"),
            partnerLabel,
            partnerName
        )
    }

    func accessibilityLabel(for slot: FreeSlot, partnerName: String) -> String {
        [title(for: slot), duration(for: slot), partnerTime(for: slot, partnerName: partnerName)]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private func window(for slot: FreeSlot) -> String {
        if slot.isAllDay { return String(localized: "freetime.slot.allday") }
        if runsToTheEndOfTheDay(slot) {
            return String.localizedStringWithFormat(String(localized: "freetime.slot.after"), time(slot.start))
        }
        return time(slot.start) + " - " + time(slot.end)
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
        date.formatted(
            Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).hour().minute()
        )
    }
}
