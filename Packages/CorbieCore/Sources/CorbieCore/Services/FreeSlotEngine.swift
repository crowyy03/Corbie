import Foundation

public struct FreeSlotEngine: Sendable {
    public static let partnerZoneLabelThreshold = 2 * 60 * 60

    private let calendar: Calendar
    private let workingHours: WorkingHours
    private let partnerTimeZone: TimeZone
    private let locale: Locale

    public init(
        calendar: Calendar = .current,
        workingHours: WorkingHours = .standard,
        partnerTimeZone: TimeZone = .current,
        locale: Locale = .current
    ) {
        var configured = calendar
        configured.locale = locale
        self.calendar = configured
        self.workingHours = workingHours
        self.partnerTimeZone = partnerTimeZone
        self.locale = locale
    }

    public func result(
        viewer: FreeSlotParticipant,
        partner: FreeSlotParticipant,
        busyRanges: [BusyRange],
        from: Date,
        to: Date,
        filters: FreeSlotFilters = FreeSlotFilters()
    ) -> FreeSlotResult {
        guard viewer.sharesBusyTimes else { return .viewerHasNoData }
        guard partner.sharesBusyTimes else { return .partnerHasNoData }
        guard to > from else { return .none }

        let busy = BusyIntervals.merged(
            busyRanges.compactMap { range in
                guard range.memberId == viewer.memberId || range.memberId == partner.memberId else { return nil }
                guard range.end > range.start else { return nil }
                return DateInterval(start: range.start, end: range.end)
            }
        )

        var slots: [FreeSlot] = []
        var day = calendar.startOfDay(for: from)
        let lastDay = calendar.startOfDay(for: to)
        while day <= lastDay {
            slots.append(contentsOf: daySlots(onDayStarting: day, busy: busy, from: from, to: to, filters: filters))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = calendar.startOfDay(for: next)
        }
        return slots.isEmpty ? .none : .slots(slots)
    }

    private func daySlots(
        onDayStarting day: Date,
        busy: [DateInterval],
        from: Date,
        to: Date,
        filters: FreeSlotFilters
    ) -> [FreeSlot] {
        if filters.weekendsOnly, calendar.isDateInWeekend(day) == false { return [] }
        guard let window = workingWindow(onDayStarting: day) else { return [] }
        var lower = max(window.start, from)
        if filters.eveningsOnly {
            guard let evening = calendar.date(
                bySettingHour: FreeSlotFilters.eveningStartHour,
                minute: 0,
                second: 0,
                of: day
            ) else { return [] }
            lower = max(lower, evening)
        }
        let upper = min(window.end, to)
        guard upper > lower else { return [] }

        return gaps(in: DateInterval(start: lower, end: upper), busy: busy)
            .filter { $0.duration >= filters.minimumDuration }
            .map { gap in
                FreeSlot(
                    start: gap.start,
                    end: gap.end,
                    isAllDay: gap.start <= window.start && gap.end >= window.end,
                    partnerLabel: partnerLabel(for: gap.start)
                )
            }
    }

    private func workingWindow(onDayStarting day: Date) -> DateInterval? {
        guard let start = calendar.date(bySettingHour: workingHours.startHour, minute: 0, second: 0, of: day),
              let end = calendar.date(bySettingHour: workingHours.endHour, minute: 0, second: 0, of: day),
              end > start else { return nil }
        return DateInterval(start: start, end: end)
    }

    private func gaps(in window: DateInterval, busy: [DateInterval]) -> [DateInterval] {
        var free: [DateInterval] = []
        var cursor = window.start
        for interval in busy where interval.end > window.start && interval.start < window.end {
            if interval.start > cursor {
                free.append(DateInterval(start: cursor, end: interval.start))
            }
            cursor = max(cursor, interval.end)
            if cursor >= window.end { break }
        }
        if cursor < window.end {
            free.append(DateInterval(start: cursor, end: window.end))
        }
        return free
    }

    private func partnerLabel(for date: Date) -> String? {
        let difference = partnerTimeZone.secondsFromGMT(for: date) - calendar.timeZone.secondsFromGMT(for: date)
        guard abs(difference) >= FreeSlotEngine.partnerZoneLabelThreshold else { return nil }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = partnerTimeZone
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter.string(from: date)
    }
}
