import CorbieCore
import Observation
import SwiftUI

@MainActor
@Observable
final class ExpenseEditorViewModel {
    var amount: Double = 0
    var currency: String
    var note = ""
    var date = Date()
    private(set) var isSaving = false
    private(set) var currencies: [String] = FXService.baseCurrencies

    @ObservationIgnored private let goal: GoalDTO
    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var didConfigure = false

    init(goal: GoalDTO) {
        self.goal = goal
        currency = goal.currency
    }


    var needsConversion: Bool { currency != goal.currency }

    var canSave: Bool { isSaving == false && amount > 0 }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
        guard didConfigure == false else { return }
        didConfigure = true
        var codes = environment.fx.supportedCurrencies()
        if codes.contains(goal.currency) == false {
            codes.insert(goal.currency, at: 0)
        }
        currencies = codes
    }

    func save() async -> Bool {
        guard let environment else { return false }
        guard environment.premiumGate.require(.create) else { return false }
        isSaving = true
        defer { isSaving = false }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let conversion = try await environment.fx.convert(
                amount: amount,
                from: currency,
                to: goal.currency
            )
            _ = try await environment.repositories.goals.addExpense(
                goalId: goal.id,
                draft: GoalExpenseDraft(
                    amount: amount,
                    currency: currency,
                    fxRateToGoalCurrency: conversion.rate,
                    note: trimmedNote.isEmpty ? nil : trimmedNote,
                    date: date,
                    addedByMemberId: environment.currentMember?.id
                )
            )
            environment.analytics.record(.expenseAdded)
            return true
        } catch {
            environment.report(error)
            return false
        }
    }
}
