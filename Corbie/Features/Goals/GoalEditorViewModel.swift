import CorbieCore
import Observation
import SwiftUI

@MainActor
@Observable
final class GoalEditorViewModel {
    var title = ""
    var type: GoalType = .other
    var targetAmount: Double = 0
    var savedAmount: Double = 0
    var currency = "USD"
    var hasDates = false
    var startAt = Date()
    var endAt = Date()
    var note = ""
    private(set) var isSaving = false
    private(set) var currencies: [String] = FXService.baseCurrencies

    @ObservationIgnored private let existing: GoalDTO?
    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var didConfigure = false

    init(goal: GoalDTO?) {
        existing = goal
        guard let goal else { return }
        title = goal.title
        type = goal.type
        targetAmount = goal.targetAmount
        savedAmount = goal.savedAmount
        currency = goal.currency
        hasDates = goal.startAt != nil || goal.endAt != nil
        startAt = goal.startAt ?? goal.endAt ?? Date()
        endAt = goal.endAt ?? goal.startAt ?? Date()
        note = goal.note ?? ""
    }

    var isEditing: Bool { existing != nil }

    var canSave: Bool {
        isSaving == false && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
        guard didConfigure == false else { return }
        didConfigure = true
        var codes = environment.fx.supportedCurrencies()
        if codes.contains(currency) == false {
            codes.insert(currency, at: 0)
        }
        currencies = codes
        if existing == nil, let space = environment.space {
            currency = space.displayCurrency
        }
    }

    func save() async -> Bool {
        guard let environment, let space = environment.space else { return false }
        guard environment.premiumGate.require(isEditing ? .edit : .create) else { return false }
        isSaving = true
        defer { isSaving = false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if var goal = existing {
                goal.title = trimmedTitle
                goal.type = type
                goal.targetAmount = targetAmount
                goal.savedAmount = savedAmount
                goal.currency = currency
                goal.startAt = hasDates ? startAt : nil
                goal.endAt = hasDates ? endAt : nil
                goal.note = trimmedNote.isEmpty ? nil : trimmedNote
                _ = try await environment.repositories.goals.update(goal)
            } else {
                _ = try await environment.repositories.goals.create(
                    GoalDraft(
                        spaceId: space.id,
                        title: trimmedTitle,
                        type: type,
                        targetAmount: targetAmount,
                        currency: currency,
                        savedAmount: savedAmount,
                        startAt: hasDates ? startAt : nil,
                        endAt: hasDates ? endAt : nil,
                        note: trimmedNote.isEmpty ? nil : trimmedNote,
                        createdByMemberId: environment.currentMember?.id
                    )
                )
                environment.analytics.record(.goalCreated(type: type))
            }
            return true
        } catch {
            environment.report(error)
            return false
        }
    }
}
