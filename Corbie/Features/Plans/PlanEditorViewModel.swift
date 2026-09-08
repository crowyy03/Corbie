import CorbieCore
import Observation
import SwiftUI

@MainActor
@Observable
final class PlanEditorViewModel {
    enum Kind: String, CaseIterable, Hashable {
        case targeted
        case open

        var titleKey: String { "plans.editor.kind." + rawValue }
    }

    var title = ""
    var kind: Kind = .targeted
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
        kind = plan.isOpenEnded ? .open : .targeted
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

    var isOpenEnded: Bool { kind == .open }

    var canSave: Bool {
        guard isSaving == false, trimmedTitle.isEmpty == false else { return false }
        return isOpenEnded || targetAmount > 0
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

    func draft(spaceId: UUID, createdByMemberId: UUID?) -> PlanDraft {
        PlanDraft(
            spaceId: spaceId,
            title: trimmedTitle,
            type: type,
            targetAmount: isOpenEnded ? 0 : targetAmount,
            currency: currency,
            savedAmount: savedAmount,
            isOpenEnded: isOpenEnded,
            startAt: hasDates ? startAt : nil,
            endAt: hasDates ? endAt : nil,
            note: trimmedNote,
            createdByMemberId: createdByMemberId
        )
    }

    func updated(_ plan: PlanDTO) -> PlanDTO {
        var edited = plan
        edited.title = trimmedTitle
        edited.type = type
        edited.isOpenEnded = isOpenEnded
        edited.targetAmount = isOpenEnded ? 0 : targetAmount
        edited.savedAmount = savedAmount
        edited.currency = currency
        edited.startAt = hasDates ? startAt : nil
        edited.endAt = hasDates ? endAt : nil
        edited.note = trimmedNote
        return edited
    }

    func save() async -> Bool {
        guard let environment, let space = environment.space else { return false }
        guard environment.premiumGate.require(isEditing ? .edit : .create) else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            if let existing {
                _ = try await environment.repositories.plans.update(updated(existing))
            } else {
                let created = try await environment.repositories.plans.create(
                    draft(spaceId: space.id, createdByMemberId: environment.currentMember?.id)
                )
                environment.analytics.record(.planCreated(type: type, isOpenEnded: created.isOpenEnded))
            }
            return true
        } catch {
            environment.report(error)
            return false
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNote: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
