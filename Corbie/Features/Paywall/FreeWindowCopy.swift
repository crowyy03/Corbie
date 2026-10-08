import CorbieCore
import Foundation

enum FreeWindowCopy {
    static func line(endsAt: Date, now: Date, calendar: Calendar = .current) -> String {
        let days = FreeWindow(endsAt: endsAt).daysAfterToday(at: now, calendar: calendar)
        guard days > 0 else { return String(localized: "paywall.freewindow.tonight") }
        return String.localizedStringWithFormat(String(localized: "paywall.freewindow.days"), days)
    }
}
