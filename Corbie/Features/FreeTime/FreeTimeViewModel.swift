import CorbieCore
import Foundation
import Observation

enum FreeTimeRange: CaseIterable, Hashable {
    case week
    case fortnight

    var days: Int {
        switch self {
        case .week: return 7
        case .fortnight: return 14
        }
    }

    var titleKey: String {
        switch self {
        case .week: return "freetime.range.week"
        case .fortnight: return "freetime.range.fortnight"
        }
    }
}

enum FreeTimeState: Equatable {
    case loading
    case notPaired
    case viewerNotSharing
    case partnerNotSharing
    case calendarDenied
    case unreadable
    case noSlots
    case slots([FreeSlot])

    static func from(_ result: FreeSlotResult) -> FreeTimeState {
        switch result {
        case let .slots(slots):
            return slots.isEmpty ? .noSlots : .slots(slots)
        case .partnerHasNoData:
            return .partnerNotSharing
        case .viewerHasNoData:
            return .viewerNotSharing
        case .none:
            return .noSlots
        }
    }

    var emptyReason: FreeTimeEmptyReason? {
        switch self {
        case .notPaired: return .notPaired
        case .viewerNotSharing: return .viewerNotSharing
        case .partnerNotSharing: return .partnerNotSharing
        case .calendarDenied: return .calendarDenied
        case .noSlots: return .noSlots
        case .loading, .unreadable, .slots: return nil
        }
    }
}

enum FreeTimeSheet: Identifiable {
    case privacy
    case editor(EventEditorTarget)

    var id: String {
        switch self {
        case .privacy: return "privacy"
        case let .editor(target): return "editor." + target.id
        }
    }
}

@MainActor
@Observable
final class FreeTimeViewModel {
    static let longSlotDuration: TimeInterval = 2 * 60 * 60

    var range: FreeTimeRange = .week
    var eveningsOnly = false
    var weekendsOnly = false
    var longSlotsOnly = false
    var sheet: FreeTimeSheet?

    private(set) var state: FreeTimeState = .loading
    private(set) var people: [PersonDTO] = []

    @ObservationIgnored let calendar: Calendar
    @ObservationIgnored let rowText: FreeTimeRowText

    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var environment: AppEnvironment?

    init(
        locale: Locale = .current,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        var configured = calendar
        configured.locale = locale
        self.calendar = configured
        self.locale = locale
        self.now = now
        rowText = FreeTimeRowText(locale: locale, calendar: configured)
    }

    var filters: FreeSlotFilters {
        FreeSlotFilters(
            eveningsOnly: eveningsOnly,
            weekendsOnly: weekendsOnly,
            minimumDuration: longSlotsOnly
                ? FreeTimeViewModel.longSlotDuration
                : FreeSlotFilters.defaultMinimumDuration
        )
    }

    func open(_ environment: AppEnvironment) async {
        self.environment = environment
        environment.analytics.record(.freetimeOpened)
        if BusyTimesPrivacyNotice.hasBeenSeen == false, sheet == nil {
            sheet = .privacy
        }
        await environment.publishBusyTimes()
        await load()
    }

    func refresh() async {
        await environment?.publishBusyTimes(force: true)
        await load()
    }

    func load() async {
        guard let environment,
              let space = environment.space,
              let member = environment.currentMember,
              let partner = environment.partner
        else {
            apply(.notPaired)
            return
        }
        let start = now()
        guard let end = calendar.date(byAdding: .day, value: range.days, to: start) else {
            apply(.unreadable)
            return
        }
        if member.sharesBusyTimes, CalendarAccess.current == .denied {
            apply(.calendarDenied)
            return
        }
        do {
            let store = RepositoryBusyIntervalStore(
                repository: environment.repositories.busyIntervals,
                spaceId: space.id
            )
            let busyRanges = try await store.intervals(spaceId: space.id, from: start, to: end)
            people = try await environment.repositories.people.people(spaceId: space.id)
            let engine = FreeSlotEngine(calendar: calendar, locale: locale)
            let result = engine.result(
                viewer: FreeSlotParticipant(memberId: member.id, sharesBusyTimes: member.sharesBusyTimes),
                partner: FreeSlotParticipant(memberId: partner.id, sharesBusyTimes: partner.sharesBusyTimes),
                busyRanges: busyRanges,
                from: start,
                to: end,
                filters: filters
            )
            apply(FreeTimeState.from(result))
        } catch {
            environment.report(error)
            apply(.unreadable)
        }
    }

    func selectSlot(_ slot: FreeSlot) {
        environment?.analytics.record(.freetimeSlotTapped)
        sheet = .editor(.createSlot(start: slot.start, end: slot.end))
    }

    func nudgePartner() {
        guard let environment else { return }
        environment.toasts.show(
            message: String.localizedStringWithFormat(
                String(localized: "freetime.partner.ask.toast"),
                environment.partnerName
            )
        )
    }

    private func apply(_ newState: FreeTimeState) {
        let isNew = state != newState
        state = newState
        guard isNew, let reason = newState.emptyReason else { return }
        environment?.analytics.record(.freetimeEmpty(reason: reason))
    }
}
