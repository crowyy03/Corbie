import Foundation
@testable import CorbieCore

enum DomainClock {
    static func calendar(locale: String = "en_US", timeZone: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: locale)
        calendar.timeZone = TimeZone(identifier: timeZone) ?? .gmt
        return calendar
    }

    static func date(_ value: String, in calendar: Calendar) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = value.count > 10 ? "yyyy-MM-dd HH:mm" : "yyyy-MM-dd"
        guard let date = formatter.date(from: value) else {
            return Date(timeIntervalSince1970: 0)
        }
        return date
    }

    static func parts(_ date: Date, in calendar: Calendar) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    static func text(_ date: Date, in calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

actor FakeNotificationCenter: NotificationCenterClient {
    private(set) var requests: [CorbieNotificationRequest] = []
    private(set) var categories: [NotificationCategoryDescriptor] = []
    private(set) var authorizationCalls = 0
    private(set) var removedIdentifiers: [String] = []
    private var status: NotificationAuthorization
    private var grants: Bool
    private let addFailure: (any Error)?

    init(
        status: NotificationAuthorization = .authorized,
        grants: Bool = true,
        addFailure: (any Error)? = nil
    ) {
        self.status = status
        self.grants = grants
        self.addFailure = addFailure
    }

    func authorizationStatus() async -> NotificationAuthorization { status }

    func requestAuthorization() async throws -> Bool {
        authorizationCalls += 1
        status = grants ? .authorized : .denied
        return grants
    }

    func registerCategories(_ categories: [NotificationCategoryDescriptor]) async {
        self.categories = categories
    }

    func pendingIdentifiers() async -> [String] {
        requests.map(\.id)
    }

    func add(_ request: CorbieNotificationRequest) async throws {
        if let addFailure { throw addFailure }
        requests.removeAll { $0.id == request.id }
        requests.append(request)
    }

    func removePending(identifiers: [String]) async {
        removedIdentifiers.append(contentsOf: identifiers)
        requests.removeAll { identifiers.contains($0.id) }
    }

    func request(id: String) -> CorbieNotificationRequest? {
        requests.first { $0.id == id }
    }
}

actor FakeEventStoreClient: EventStoreClient {
    private(set) var accessCalls = 0
    private(set) var lastRange: (from: Date, to: Date)?
    private(set) var lastCalendarIds: [String] = []
    private let storedCalendars: [ImportedCalendar]
    private let storedEvents: [ImportedEvent]
    private let grants: Bool

    init(calendars: [ImportedCalendar] = [], events: [ImportedEvent] = [], grants: Bool = true) {
        storedCalendars = calendars
        storedEvents = events
        self.grants = grants
    }

    func requestAccess() async throws -> Bool {
        accessCalls += 1
        return grants
    }

    func calendars() async throws -> [ImportedCalendar] { storedCalendars }

    func events(calendarIds: [String], from: Date, to: Date) async throws -> [ImportedEvent] {
        lastRange = (from, to)
        lastCalendarIds = calendarIds
        return storedEvents.filter { calendarIds.contains($0.calendarId) }
    }
}
