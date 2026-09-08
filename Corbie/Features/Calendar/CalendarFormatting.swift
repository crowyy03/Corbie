import CorbieCore
import Foundation
import SwiftUI

struct CalendarFormatting {
    let locale: Locale
    let calendar: Calendar

    init(locale: Locale = .current, calendar: Calendar = .current) {
        self.locale = locale
        var configured = calendar
        configured.locale = locale
        self.calendar = configured
    }

    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }

    var weekdaySymbols: [String] {
        CalendarGrid.weekdaySymbols(calendar: calendar, locale: locale)
    }

    func monthTitle(_ month: Date) -> String {
        month.formatted(dateStyle.month(.wide).year())
    }

    func dayNumber(_ day: Date) -> String {
        calendar.component(.day, from: day).formatted(.number.locale(locale))
    }

    func relativeCaption(for entry: CalendarEntry, now: Date) -> String {
        RelativeDateText(locale: locale, calendar: calendar).relativeDay(for: entry.startDay, now: now)
    }

    func title(for entry: CalendarEntry) -> String {
        switch entry.source {
        case let .event(event):
            return event.title
        case let .autoDate(autoDate):
            return title(for: autoDate)
        }
    }

    func title(for autoDate: AutoDate) -> String {
        switch autoDate.kind {
        case .anniversary:
            guard let years = autoDate.years else { return String(localized: "calendar.autodate.togethersince") }
            return String.localizedStringWithFormat(String(localized: "calendar.autodate.anniversary"), years)
        case .wedding:
            guard let years = autoDate.years else { return String(localized: "calendar.autodate.wedding") }
            return String.localizedStringWithFormat(String(localized: "calendar.autodate.married"), years)
        case .memberBirthday, .personBirthday:
            guard let name = autoDate.name, name.isEmpty == false else {
                return String(localized: "calendar.autodate.birthday")
            }
            if let withAge = PersonDateText.birthdayTitle(person: name, ordinal: autoDate.years, locale: locale) {
                return withAge
            }
            return String.localizedStringWithFormat(String(localized: "calendar.autodate.namedbirthday"), name)
        case .event:
            guard let name = autoDate.name, name.isEmpty == false else {
                return String(localized: "calendar.kind.event")
            }
            return name
        }
    }

    func schedule(for entry: CalendarEntry) -> String {
        let start = entry.startAt
        let end = entry.endAt
        if entry.isAllDay {
            guard entry.spansDays else { return String(localized: "calendar.event.allday") }
            return join(start.formatted(dateStyle.day().month(.abbreviated)),
                        entry.endDay.formatted(dateStyle.day().month(.abbreviated)))
        }
        guard entry.spansDays else {
            let startTime = start.formatted(dateStyle.hour().minute())
            guard let end else { return startTime }
            return join(startTime, end.formatted(dateStyle.hour().minute()))
        }
        let startText = start.formatted(dateStyle.day().month(.abbreviated).hour().minute())
        guard let end else { return startText }
        return join(startText, end.formatted(dateStyle.day().month(.abbreviated).hour().minute()))
    }

    func monthCaption(_ day: Date) -> String {
        day.formatted(dateStyle.month(.abbreviated))
    }

    func shortDate(_ day: Date) -> String {
        day.formatted(dateStyle.weekday(.abbreviated).day().month(.abbreviated))
    }

    func longDate(_ day: Date) -> String {
        day.formatted(dateStyle.weekday(.wide).day().month(.wide))
    }

    func commentTimestamp(_ date: Date) -> String {
        date.formatted(dateStyle.day().month(.abbreviated).hour().minute())
    }

    func kindLabel(_ kind: EventKind) -> String {
        switch kind {
        case .event: return String(localized: "calendar.kind.event")
        case .birthday: return String(localized: "calendar.kind.birthday")
        case .anniversary: return String(localized: "calendar.kind.anniversary")
        case .trip: return String(localized: "calendar.kind.trip")
        }
    }

    func reminderLabel(_ offset: ReminderOffset) -> String {
        switch offset {
        case .dayBefore: return String(localized: "calendar.reminder.daybefore")
        case .threeDaysBefore: return String(localized: "calendar.reminder.threedays")
        case .twoWeeksBefore: return String(localized: "calendar.reminder.twoweeks")
        }
    }

    func radarCaption(for line: RadarLine) -> String {
        if line.status.giftPicked {
            return String(localized: "calendar.radar.picked")
        }
        guard line.status.ideasCount > 0 else { return String(localized: "calendar.radar.noideas") }
        return String.localizedStringWithFormat(String(localized: "calendar.radar.ideas"), line.status.ideasCount)
    }

    func dayAccessibilityLabel(_ day: Date, entryCount: Int) -> String {
        let date = longDate(day)
        guard entryCount > 0 else { return date }
        let count = String.localizedStringWithFormat(String(localized: "calendar.day.entrycount"), entryCount)
        return date + ", " + count
    }

    private func join(_ lhs: String, _ rhs: String) -> String {
        lhs + " - " + rhs
    }
}

enum CalendarEntryTint {
    @MainActor
    static func color(for entry: CalendarEntry, in environment: AppEnvironment, palette: ThemePalette) -> Color {
        guard let slot = environment.memberSlot(id: entry.ownerMemberId) else { return palette.accent }
        return palette.member(slot)
    }
}
