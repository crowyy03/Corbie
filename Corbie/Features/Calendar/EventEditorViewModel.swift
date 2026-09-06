import CorbieCore
import Foundation
import Observation

enum EventEditorTarget: Identifiable, Equatable {
    case create(Date)
    case edit(EventDTO)

    var id: String {
        switch self {
        case let .create(date):
            return "create." + String(Int(date.timeIntervalSinceReferenceDate.rounded()))
        case let .edit(event):
            return "edit." + event.id.uuidString
        }
    }
}

@MainActor
@Observable
final class EventEditorViewModel {
    static let defaultDurationMinutes = 60
    static let allDayEndHour = 23
    static let allDayEndMinute = 59
    static let allDayEndSecond = 59

    var title: String
    var isAllDay: Bool
    var start: Date
    var end: Date
    var kind: EventKind
    var personId: UUID?
    var note: String
    var reminders: Set<ReminderOffset>
    var place: MapPlace?
    private(set) var isSaving = false

    @ObservationIgnored let existing: EventDTO?
    @ObservationIgnored let people: [PersonDTO]
    @ObservationIgnored let calendar: Calendar
    @ObservationIgnored let formatting: CalendarFormatting

    init(target: EventEditorTarget, people: [PersonDTO], calendar: Calendar, locale: Locale = .current) {
        var configured = calendar
        configured.locale = locale
        self.calendar = configured
        self.people = people
        formatting = CalendarFormatting(locale: locale, calendar: configured)
        switch target {
        case let .create(date):
            existing = nil
            title = ""
            isAllDay = false
            start = date
            end = configured.date(byAdding: .minute, value: Self.defaultDurationMinutes, to: date) ?? date
            kind = .event
            personId = nil
            note = ""
            reminders = []
            place = nil
        case let .edit(event):
            existing = event
            title = event.title
            isAllDay = event.isAllDay
            let startAt = event.startAt ?? Date()
            start = startAt
            if event.isAllDay {
                end = CalendarEntry.inclusiveEndDay(
                    startAt: startAt,
                    endAt: event.endAt,
                    isAllDay: true,
                    calendar: configured
                )
            } else {
                end = event.endAt
                    ?? configured.date(byAdding: .minute, value: Self.defaultDurationMinutes, to: startAt)
                    ?? startAt
            }
            kind = event.kind
            personId = event.personId
            note = event.note ?? ""
            reminders = Set(event.reminderOffsets)
            place = MapPlace(event: event)
        }
    }

    var isEditing: Bool { existing != nil }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool { trimmedTitle.isEmpty == false && isSaving == false }

    var showsPersonPicker: Bool { kind == .birthday }

    func toggle(_ offset: ReminderOffset) {
        if reminders.contains(offset) {
            reminders.remove(offset)
        } else {
            reminders.insert(offset)
        }
    }

    func startChanged() {
        guard end < start else { return }
        end = calendar.date(byAdding: .minute, value: Self.defaultDurationMinutes, to: start) ?? start
    }

    func endChanged() {
        guard end < start else { return }
        end = start
    }

    func save(_ environment: AppEnvironment) async -> Bool {
        guard let space = environment.space, canSave else { return false }
        isSaving = true
        defer { isSaving = false }
        let dates = resolvedDates()
        do {
            let saved: EventDTO
            if var event = existing {
                event.title = trimmedTitle
                event.startAt = dates.start
                event.endAt = dates.end
                event.isAllDay = isAllDay
                event.kind = kind
                event.personId = showsPersonPicker ? personId : nil
                event.locationName = place?.name
                event.address = place?.address
                event.latitude = place?.latitude
                event.longitude = place?.longitude
                event.note = trimmedNote
                event.reminderOffsets = sortedReminders
                saved = try await environment.repositories.events.update(event)
            } else {
                let draft = EventDraft(
                    spaceId: space.id,
                    title: trimmedTitle,
                    startAt: dates.start,
                    endAt: dates.end,
                    isAllDay: isAllDay,
                    kind: kind,
                    personId: showsPersonPicker ? personId : nil,
                    locationName: place?.name,
                    address: place?.address,
                    latitude: place?.latitude,
                    longitude: place?.longitude,
                    note: trimmedNote,
                    reminderOffsets: sortedReminders,
                    createdByMemberId: environment.currentMember?.id
                )
                saved = try await environment.repositories.events.create(draft)
                environment.analytics.record(.eventCreated(kind: kind))
            }
            await scheduleNotifications(for: saved, environment: environment)
            return true
        } catch {
            environment.report(error)
            return false
        }
    }

    private var trimmedNote: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var sortedReminders: [ReminderOffset] {
        reminders.sorted { $0.days > $1.days }
    }

    private func resolvedDates() -> (start: Date, end: Date?) {
        guard isAllDay else {
            return (start, max(end, start))
        }
        let first = calendar.startOfDay(for: start)
        let last = max(calendar.startOfDay(for: end), first)
        let closing = calendar.date(
            bySettingHour: Self.allDayEndHour,
            minute: Self.allDayEndMinute,
            second: Self.allDayEndSecond,
            of: last
        )
        return (first, closing ?? last)
    }

    private func scheduleNotifications(for event: EventDTO, environment: AppEnvironment) async {
        _ = try? await environment.notifications.requestAuthorizationIfNeeded()
        let prefs = environment.currentMember?.notificationPrefs ?? .allEnabled
        let now = Date()
        do {
            try await environment.notifications.scheduleEventReminders(for: event, prefs: prefs, now: now)
            try await environment.notifications.scheduleEventDigest(for: event, prefs: prefs, now: now)
        } catch {
            environment.report(error)
        }
    }
}
