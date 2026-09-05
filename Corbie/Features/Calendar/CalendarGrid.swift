import Foundation

struct CalendarWeek: Identifiable, Equatable {
    let index: Int
    let days: [Date]

    var id: Int { index }
    var first: Date? { days.first }
    var last: Date? { days.last }
}

struct CalendarSpan: Identifiable, Equatable {
    let entryId: String
    let weekIndex: Int
    let startColumn: Int
    let length: Int
    let continuesBefore: Bool
    let continuesAfter: Bool
    let lane: Int

    var id: String { entryId + "." + String(weekIndex) }
}

struct CalendarGrid: Equatable {
    static let columns = 7

    let calendar: Calendar
    let monthStart: Date
    let weeks: [CalendarWeek]

    init(month date: Date, calendar: Calendar) {
        self.calendar = calendar
        let start = calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        monthStart = start
        let weekday = calendar.component(.weekday, from: start)
        let leading = (weekday - calendar.firstWeekday + CalendarGrid.columns) % CalendarGrid.columns
        let daysInMonth = calendar.range(of: .day, in: .month, for: start)?.count ?? CalendarGrid.columns
        let gridStart = calendar.date(byAdding: .day, value: -leading, to: start).map(calendar.startOfDay(for:)) ?? start
        let weekCount = Int((Double(leading + daysInMonth) / Double(CalendarGrid.columns)).rounded(.up))
        weeks = (0..<max(weekCount, 1)).map { weekIndex in
            let days = (0..<CalendarGrid.columns).compactMap { column -> Date? in
                let offset = weekIndex * CalendarGrid.columns + column
                return calendar.date(byAdding: .day, value: offset, to: gridStart).map(calendar.startOfDay(for:))
            }
            return CalendarWeek(index: weekIndex, days: days)
        }
    }

    var firstDay: Date { weeks.first?.first ?? monthStart }

    var lastDay: Date { weeks.last?.last ?? monthStart }

    func isInMonth(_ day: Date) -> Bool {
        calendar.isDate(day, equalTo: monthStart, toGranularity: .month)
    }

    func month(offsetBy months: Int) -> Date {
        calendar.date(byAdding: .month, value: months, to: monthStart) ?? monthStart
    }

    func spans(for entries: [CalendarEntry]) -> [CalendarSpan] {
        weeks.flatMap { spans(for: entries, in: $0) }
    }

    func laneCount(in weekIndex: Int, spans: [CalendarSpan]) -> Int {
        spans.filter { $0.weekIndex == weekIndex }.map { $0.lane + 1 }.max() ?? 0
    }

    static func weekdaySymbols(calendar: Calendar, locale: Locale) -> [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? []
        guard symbols.count == columns else { return symbols }
        let offset = max(calendar.firstWeekday - 1, 0) % columns
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private func spans(for entries: [CalendarEntry], in week: CalendarWeek) -> [CalendarSpan] {
        guard let weekStart = week.first, let weekEnd = week.last else { return [] }
        let candidates = entries
            .filter { $0.spansDays && $0.startDay <= weekEnd && $0.endDay >= weekStart }
            .sorted { lhs, rhs in
                if lhs.startDay != rhs.startDay { return lhs.startDay < rhs.startDay }
                if lhs.endDay != rhs.endDay { return lhs.endDay > rhs.endDay }
                return lhs.id < rhs.id
            }
        var lanes: [[ClosedRange<Int>]] = []
        var result: [CalendarSpan] = []
        for entry in candidates {
            let startColumn = column(of: max(entry.startDay, weekStart), in: week) ?? 0
            let endColumn = column(of: min(entry.endDay, weekEnd), in: week) ?? (CalendarGrid.columns - 1)
            guard endColumn >= startColumn else { continue }
            let range = startColumn...endColumn
            let lane = claimLane(&lanes, range: range)
            result.append(
                CalendarSpan(
                    entryId: entry.id,
                    weekIndex: week.index,
                    startColumn: startColumn,
                    length: endColumn - startColumn + 1,
                    continuesBefore: entry.startDay < weekStart,
                    continuesAfter: entry.endDay > weekEnd,
                    lane: lane
                )
            )
        }
        return result
    }

    private func column(of day: Date, in week: CalendarWeek) -> Int? {
        week.days.firstIndex { calendar.isDate($0, inSameDayAs: day) }
    }

    private func claimLane(_ lanes: inout [[ClosedRange<Int>]], range: ClosedRange<Int>) -> Int {
        for index in lanes.indices where lanes[index].allSatisfy({ $0.overlaps(range) == false }) {
            lanes[index].append(range)
            return index
        }
        lanes.append([range])
        return lanes.count - 1
    }
}
