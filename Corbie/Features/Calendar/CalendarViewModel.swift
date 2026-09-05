import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class CalendarViewModel {
    static let upcomingLimit = 20
    static let upcomingHorizonDays = 365
    static let defaultStartHour = 19
    static let reloadDebounce = Duration.milliseconds(250)

    private(set) var grid: CalendarGrid
    private(set) var entries: [CalendarEntry] = []
    private(set) var spans: [CalendarSpan] = []
    private(set) var entriesByDay: [Date: [CalendarEntry]] = [:]
    private(set) var upcoming: [CalendarEntry] = []
    private(set) var radar: [String: RadarLine] = [:]
    private(set) var people: [PersonDTO] = []
    private(set) var isLoading = false
    var selectedDay: Date?

    @ObservationIgnored let calendar: Calendar
    @ObservationIgnored let formatting: CalendarFormatting
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private var reloadTask: Task<Void, Never>?

    init(
        calendar: Calendar = .current,
        locale: Locale = .current,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        var configured = calendar
        configured.locale = locale
        self.calendar = configured
        self.clock = clock
        formatting = CalendarFormatting(locale: locale, calendar: configured)
        grid = CalendarGrid(month: clock(), calendar: configured)
    }

    var now: Date { clock() }

    var today: Date { calendar.startOfDay(for: clock()) }

    var monthTitle: String { formatting.monthTitle(grid.monthStart) }

    var isOnCurrentMonth: Bool {
        calendar.isDate(grid.monthStart, equalTo: clock(), toGranularity: .month)
    }

    var sectionEntries: [CalendarEntry] {
        guard let selectedDay else { return upcoming }
        return entries.filter { $0.covers(selectedDay, calendar: calendar) }
    }

    func step(months: Int) {
        grid = CalendarGrid(month: grid.month(offsetBy: months), calendar: calendar)
        selectedDay = nil
        refreshDerived()
    }

    func showCurrentMonth() {
        grid = CalendarGrid(month: clock(), calendar: calendar)
        selectedDay = nil
        refreshDerived()
    }

    func select(_ day: Date) {
        let target = calendar.startOfDay(for: day)
        selectedDay = selectedDay == target ? nil : target
    }

    func entries(on day: Date) -> [CalendarEntry] {
        entriesByDay[calendar.startOfDay(for: day)] ?? []
    }

    func isToday(_ day: Date) -> Bool {
        calendar.isDate(day, inSameDayAs: clock())
    }

    func radarLine(for entry: CalendarEntry) -> RadarLine? {
        guard let autoDate = entry.autoDate else { return nil }
        return radar[autoDate.id]
    }

    func draftStart() -> Date {
        let day = selectedDay ?? today
        return calendar.date(bySettingHour: Self.defaultStartHour, minute: 0, second: 0, of: day) ?? day
    }

    func scheduleReload(_ environment: AppEnvironment) {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            try? await Task.sleep(for: Self.reloadDebounce)
            guard Task.isCancelled == false else { return }
            await self?.load(environment)
        }
    }

    func load(_ environment: AppEnvironment) async {
        guard let space = environment.space else {
            entries = []
            people = []
            radar = [:]
            refreshDerived()
            return
        }
        isLoading = true
        defer { isLoading = false }
        let now = clock()
        do {
            let people = try await environment.repositories.people.people(spaceId: space.id)
            let events = try await environment.repositories.events.events(
                spaceId: space.id,
                from: rangeStart(now: now),
                to: rangeEnd(now: now)
            )
            let members = [environment.currentMember, environment.partner].compactMap { $0 }
            self.people = people
            entries = CalendarEntries.merge(
                events: events,
                autoDates: autoDates(space: space, members: members, people: people, now: now),
                calendar: calendar
            )
            refreshDerived()
            radar = await radarLines(
                environment: environment,
                space: space,
                members: members,
                people: people,
                now: now
            )
        } catch {
            environment.report(error)
        }
    }

    private func refreshDerived() {
        let now = clock()
        spans = grid.spans(for: entries)
        entriesByDay = CalendarEntries.entriesByDay(entries, calendar: calendar)
        upcoming = CalendarEntries.upcoming(entries, from: now, calendar: calendar, limit: Self.upcomingLimit)
    }

    private func rangeStart(now: Date) -> Date {
        min(grid.firstDay, calendar.startOfDay(for: now))
    }

    private func rangeEnd(now: Date) -> Date {
        let horizon = calendar.date(byAdding: .day, value: Self.upcomingHorizonDays, to: now) ?? now
        return max(grid.lastDay, horizon)
    }

    private func autoDates(space: SpaceDTO, members: [MemberDTO], people: [PersonDTO], now: Date) -> [AutoDate] {
        let provider = AutoDatesProvider(calendar: calendar)
        var seen = Set<String>()
        var result: [AutoDate] = []
        for anchor in [now, grid.firstDay] {
            for autoDate in provider.autoDates(space: space, members: members, people: people, now: anchor) {
                let key = autoDate.id + "." + CalendarEntries.dayKey(calendar.startOfDay(for: autoDate.date))
                guard seen.insert(key).inserted else { continue }
                result.append(autoDate)
            }
        }
        return result
    }

    private func radarLines(
        environment: AppEnvironment,
        space: SpaceDTO,
        members: [MemberDTO],
        people: [PersonDTO],
        now: Date
    ) async -> [String: RadarLine] {
        var partnerWishes: [WishDTO] = []
        if let partnerId = environment.partner?.id {
            let query = WishQuery(spaceId: space.id, owner: .member(partnerId), fulfilled: nil)
            partnerWishes = (try? await environment.repositories.wishes.wishes(query)) ?? []
        }
        let input = RadarInput(
            space: space,
            members: members,
            people: people,
            partnerWishes: partnerWishes,
            viewerMemberId: environment.currentMember?.id
        )
        let lines = RadarService(calendar: calendar).lines(input, now: now)
        return Dictionary(lines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
