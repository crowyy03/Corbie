import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class CalendarImportViewModel {
    enum Phase: Equatable {
        case idle
        case denied
        case picking
        case importing
        case finished(Int)
    }

    private(set) var phase: Phase = .idle
    private(set) var calendars: [ImportedCalendar] = []
    private(set) var selection: Set<String> = []

    @ObservationIgnored private let service: CalendarImport

    init(client: any EventStoreClient = SystemEventStoreClient(), calendar: Calendar = .current) {
        service = CalendarImport(client: client, calendar: calendar)
    }

    var canImport: Bool {
        guard case .picking = phase else { return false }
        return selection.isEmpty == false
    }


    func toggle(_ identifier: String) {
        if selection.contains(identifier) {
            selection.remove(identifier)
        } else {
            selection.insert(identifier)
        }
    }

    func prepare(_ environment: AppEnvironment) async {
        guard phase == .idle else { return }
        do {
            guard try await service.requestAccess() else {
                phase = .denied
                return
            }
            calendars = try await service.calendars()
            phase = .picking
        } catch {
            environment.report(error)
            phase = .denied
        }
    }

    func runImport(_ environment: AppEnvironment) async {
        guard let space = environment.space, canImport else { return }
        phase = .importing
        do {
            let existing = try await environment.repositories.events.events(spaceId: space.id)
            let drafts = try await service.drafts(
                calendarIds: Array(selection),
                spaceId: space.id,
                createdByMemberId: environment.currentMember?.id,
                existing: existing
            )
            for draft in drafts {
                _ = try await environment.repositories.events.create(draft)
            }
            phase = .finished(drafts.count)
        } catch {
            environment.report(error)
            phase = .picking
        }
    }
}
