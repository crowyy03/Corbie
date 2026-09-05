import CorbieCore
import Observation
import SwiftUI

@MainActor
@Observable
final class ListEditorViewModel {
    var title = ""
    var subtitle = ""
    var template: ListTemplate = .empty
    var anyoneCanCheck = true
    private(set) var isSaving = false

    @ObservationIgnored private let existing: ChecklistListDTO?
    @ObservationIgnored private var environment: AppEnvironment?

    init(list: ChecklistListDTO?) {
        existing = list
        guard let list else { return }
        title = list.title
        subtitle = list.subtitle ?? ""
        template = list.template
        anyoneCanCheck = list.anyoneCanCheck
    }

    var isEditing: Bool { existing != nil }

    var canSave: Bool {
        isSaving == false && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var subtitlePlaceholder: String {
        PlansCopy.text(template.hintKey)
    }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
    }

    func save() async -> Bool {
        guard let environment, let space = environment.space else { return false }
        guard environment.premiumGate.require(isEditing ? .edit : .create) else { return false }
        isSaving = true
        defer { isSaving = false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if var list = existing {
                list.title = trimmedTitle
                list.subtitle = trimmedSubtitle.isEmpty ? nil : trimmedSubtitle
                list.template = list.isPinnedShopping ? list.template : template
                list.anyoneCanCheck = anyoneCanCheck
                _ = try await environment.repositories.lists.update(list)
            } else {
                _ = try await environment.repositories.lists.create(
                    ChecklistDraft(
                        spaceId: space.id,
                        title: trimmedTitle,
                        subtitle: trimmedSubtitle.isEmpty ? nil : trimmedSubtitle,
                        template: template,
                        anyoneCanCheck: anyoneCanCheck,
                        createdByMemberId: environment.currentMember?.id
                    )
                )
                environment.analytics.record(.listCreated(template: template))
            }
            return true
        } catch {
            environment.report(error)
            return false
        }
    }
}
