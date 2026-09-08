import CorbieCore
import Observation
import SwiftUI

@MainActor
@Observable
final class ExpenseEditorViewModel {
    var amount: Double = 0
    var currency: String
    var isWithdrawal = false
    var note = ""
    var date = Date()
    private(set) var isSaving = false
    private(set) var currencies: [String] = FXService.baseCurrencies

    @ObservationIgnored private let plan: PlanDTO
    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var didConfigure = false

    init(plan: PlanDTO) {
        self.plan = plan
        currency = plan.currency
    }

    var allowsWithdrawal: Bool { plan.isOpenEnded }

    var needsConversion: Bool { currency != plan.currency }

    var canSave: Bool { isSaving == false && amount > 0 }

    var signedAmount: Double { isWithdrawal ? -amount : amount }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
        guard didConfigure == false else { return }
        didConfigure = true
        var codes = environment.fx.supportedCurrencies()
        if codes.contains(plan.currency) == false {
            codes.insert(plan.currency, at: 0)
        }
        currencies = codes
    }

    func draft(rate: Double, addedByMemberId: UUID?) -> PlanExpenseDraft {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return PlanExpenseDraft(
            amount: signedAmount,
            currency: currency,
            fxRateToPlanCurrency: rate,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            date: date,
            addedByMemberId: addedByMemberId
        )
    }

    func save() async -> Bool {
        guard let environment else { return false }
        guard environment.premiumGate.require(.create) else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            let conversion = try await environment.fx.convert(
                amount: amount,
                from: currency,
                to: plan.currency
            )
            let expense = try await environment.repositories.plans.addExpense(
                planId: plan.id,
                draft: draft(rate: conversion.rate, addedByMemberId: environment.currentMember?.id)
            )
            environment.analytics.record(.expenseAdded(isNegative: expense.isWithdrawal))
            return true
        } catch {
            environment.report(error)
            return false
        }
    }
}
