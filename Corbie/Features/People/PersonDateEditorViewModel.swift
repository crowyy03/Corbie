import CorbieCore
import Foundation
import Observation

enum PersonDateEditorMode: Identifiable {
    case new
    case existing(PersonDateDTO)

    var id: String {
        switch self {
        case .new: return "new"
        case let .existing(date): return date.id.uuidString
        }
    }

    var date: PersonDateDTO? {
        switch self {
        case .new: return nil
        case let .existing(date): return date
        }
    }
}

@MainActor
@Observable
final class PersonDateEditorViewModel {
    var title: String
    var month: Int
    var day: Int
    var year: Int?
    var remindersEnabled: Bool
    private(set) var isSaving = false

    @ObservationIgnored let personId: UUID
    @ObservationIgnored let mode: PersonDateEditorMode
    @ObservationIgnored private var environment: AppEnvironment?

    init(personId: UUID, mode: PersonDateEditorMode, now: Date = Date(), calendar: Calendar = .current) {
        self.personId = personId
        self.mode = mode
        let date = mode.date
        title = date?.title ?? ""
        month = date?.month ?? calendar.component(.month, from: now)
        day = date?.day ?? calendar.component(.day, from: now)
        year = date?.year
        remindersEnabled = date?.remindersEnabled ?? true
        normalizeDay()
    }

    func bind(_ environment: AppEnvironment) {
        self.environment = environment
    }

    var canSave: Bool {
        isSaving == false && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func normalizeDay() {
        day = PersonBirthday.clampDay(day, month: month)
    }

    func save() async -> Bool {
        guard let environment else { return false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            switch mode {
            case .new:
                _ = try await environment.repositories.people.addDate(
                    personId: personId,
                    draft: PersonDateDraft(
                        title: trimmedTitle,
                        month: month,
                        day: day,
                        year: year,
                        remindersEnabled: remindersEnabled
                    )
                )
            case .existing(var date):
                date.title = trimmedTitle
                date.month = month
                date.day = day
                date.year = year
                date.remindersEnabled = remindersEnabled
                _ = try await environment.repositories.people.updateDate(date)
            }
            return true
        } catch {
            environment.report(error)
            return false
        }
    }
}
