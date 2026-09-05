import CorbieCore
import Observation
import SwiftUI

@MainActor
@Observable
final class PlanEditorViewModel {
    var title = ""
    var type: PlanType = .other
    var targetAmount: Double = 0
    var savedAmount: Double = 0
    var currency = "USD"
    var hasDates = false
    var startAt = Date()
    var endAt = Date()
    var note = ""
    private(set) var isSaving = false
    private(set) var currencies: [String] = FXService.baseCurrencies

    @ObservationIgnored private let existing: PlanDTO?
    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var didConfigure = false

    init(plan: PlanDTO?) {
        existing = plan
        guard let plan else { return }
        title = plan.title
        type = plan.type
        targetAmount = plan.targetAmount
        savedAmount = plan.savedAmount
        currency = plan.currency
        hasDates = plan.startAt != nil || plan.endAt != nil
        startAt = plan.startAt ?? plan.endAt ?? Date()
        endAt = plan.endAt ?? plan.startAt ?? Date()
        note = plan.note ?? ""
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
            if var plan = existing {
                plan.title = trimmedTitle
                plan.type = type
                plan.targetAmount = targetAmount
                plan.savedAmount = savedAmount
                plan.currency = currency
                plan.startAt = hasDates ? startAt : nil
                plan.endAt = hasDates ? endAt : nil
                plan.note = trimmedNote.isEmpty ? nil : trimmedNote
                _ = try await environment.repositories.plans.update(plan)
            } else {
                _ = try await environment.repositories.plans.create(
                    PlanDraft(
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
                environment.analytics.record(.planCreated(type: type))
            }
            return true
        } catch {
            environment.report(error)
            return false
        }
    }
}
