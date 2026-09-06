import CorbieCore
import EventKit
import Foundation
import Observation

@MainActor
@Observable
final class EventDetailViewModel {
    private(set) var event: EventDTO?
    private(set) var comments: [EventCommentDTO] = []
    private(set) var person: PersonDTO?
    private(set) var people: [PersonDTO] = []
    private(set) var isSending = false
    private(set) var isDeleted = false
    var draft = ""

    @ObservationIgnored let eventId: UUID
    @ObservationIgnored let calendar: Calendar
    @ObservationIgnored let formatting: CalendarFormatting
    @ObservationIgnored let systemStore = EKEventStore()

    init(eventId: UUID, calendar: Calendar = .current, locale: Locale = .current) {
        self.eventId = eventId
        var configured = calendar
        configured.locale = locale
        self.calendar = configured
        formatting = CalendarFormatting(locale: locale, calendar: configured)
    }

    var commentLimit: Int { EventComment.maxLength }

    var remainingCharacters: Int { commentLimit - draft.count }

    var canSend: Bool {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty == false && trimmed.count <= commentLimit && isSending == false
    }

    var entry: CalendarEntry? {
        guard let event else { return nil }
        return CalendarEntry(event: event, calendar: calendar)
    }

    func load(_ environment: AppEnvironment) async {
        do {
            event = try await environment.repositories.events.event(id: eventId)
            comments = try await environment.repositories.events.comments(eventId: eventId)
            guard let space = environment.space else { return }
            people = try await environment.repositories.people.people(spaceId: space.id)
            person = people.first { $0.id == event?.personId }
        } catch {
            environment.report(error)
        }
    }

    func addComment(_ environment: AppEnvironment) async {
        guard canSend else { return }
        isSending = true
        defer { isSending = false }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await environment.repositories.events.addComment(
                eventId: eventId,
                memberId: environment.currentMember?.id,
                text: text
            )
            draft = ""
            comments = try await environment.repositories.events.comments(eventId: eventId)
        } catch {
            environment.report(error)
        }
    }

    func delete(_ environment: AppEnvironment) async {
        do {
            await environment.notifications.cancelEventReminders(eventId: eventId)
            await environment.notifications.cancelEventDigest(eventId: eventId)
            try await environment.repositories.events.delete(id: eventId)
            isDeleted = true
        } catch {
            environment.report(error)
        }
    }

    func requestSystemCalendarAccess() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly:
            return true
        case .notDetermined:
            return (try? await systemStore.requestWriteOnlyAccessToEvents()) ?? false
        default:
            return false
        }
    }
}
