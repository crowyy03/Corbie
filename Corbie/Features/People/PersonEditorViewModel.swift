import CorbieCore
import Foundation
import Observation

enum PersonOwner: Hashable, CaseIterable {
    case me
    case partner
}

@MainActor
@Observable
final class PersonEditorViewModel {
    var name: String
    var relation: String
    var birthdayMonth: Int?
    var birthdayDay: Int
    var birthdayYear: Int?
    var owner: PersonOwner
    var note: String
    private(set) var isSaving = false

    @ObservationIgnored let mode: PersonEditorMode
    @ObservationIgnored private var environment: AppEnvironment?

    init(mode: PersonEditorMode) {
        self.mode = mode
        let person = mode.person
        name = person?.name ?? ""
        relation = person?.relation ?? ""
        birthdayMonth = person?.birthdayMonth
        birthdayDay = person?.birthdayDay ?? 1
        birthdayYear = person?.birthdayYear
        owner = .me
        note = person?.note ?? ""
    }

    func bind(_ environment: AppEnvironment) {
        let isFirstBind = self.environment == nil
        self.environment = environment
        guard isFirstBind else { return }
        normalizeDay()
        if let person = mode.person, let partner = environment.partner {
            owner = person.ownerMemberId == partner.id ? .partner : .me
        }
    }

    var suggestions: [RelationSuggestion] { RelationSuggestion.matching(relation) }

    var canSave: Bool {
        isSaving == false && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func apply(_ suggestion: RelationSuggestion) {
        relation = suggestion.title()
    }

    func normalizeDay() {
        guard let birthdayMonth else { return }
        birthdayDay = PersonBirthday.clampDay(birthdayDay, month: birthdayMonth)
    }

    func save() async -> Bool {
        guard let environment, let space = environment.space else { return false }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            switch mode {
            case .new:
                _ = try await environment.repositories.people.create(
                    PersonDraft(
                        spaceId: space.id,
                        name: trimmedName,
                        relation: trimmed(relation),
                        birthdayMonth: birthdayMonth,
                        birthdayDay: birthdayMonth == nil ? nil : birthdayDay,
                        birthdayYear: birthdayMonth == nil ? nil : birthdayYear,
                        ownerMemberId: ownerMemberId(environment),
                        note: trimmed(note)
                    )
                )
            case .existing(var person):
                person.name = trimmedName
                person.relation = trimmed(relation)
                person.birthdayMonth = birthdayMonth
                person.birthdayDay = birthdayMonth == nil ? nil : birthdayDay
                person.birthdayYear = birthdayMonth == nil ? nil : birthdayYear
                person.ownerMemberId = ownerMemberId(environment)
                person.note = trimmed(note)
                _ = try await environment.repositories.people.update(person)
            }
            return true
        } catch {
            environment.report(error)
            return false
        }
    }

    private func ownerMemberId(_ environment: AppEnvironment) -> UUID? {
        switch owner {
        case .me: return environment.currentMember?.id
        case .partner: return environment.partner?.id ?? environment.currentMember?.id
        }
    }

    private func trimmed(_ value: String) -> String? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}
