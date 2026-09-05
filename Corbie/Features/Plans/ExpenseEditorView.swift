import CorbieCore
import SwiftUI

struct ExpenseEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: ExpenseEditorViewModel

    init(plan: PlanDTO) {
        _model = State(initialValue: ExpenseEditorViewModel(plan: plan))
    }

    var body: some View {
        PlansEditorScaffold(
            title: String(localized: "plans.expense.title"),
            saveTitle: String(localized: "common.action.save"),
            canSave: model.canSave,
            onCancel: { dismiss() },
            onSave: {
                Task {
                    if await model.save() { dismiss() }
                }
            }
        ) {
            PlansAmountField(
                label: String(localized: "plans.expense.field.amount"),
                amount: $model.amount
            )
            PlansCurrencyField(
                label: String(localized: "plans.expense.field.currency"),
                currencies: model.currencies,
                selection: $model.currency
            )
            PlansNoteField(
                label: String(localized: "plans.expense.field.note"),
                placeholder: String(localized: "plans.expense.field.note.placeholder"),
                text: $model.note
            )
            PlansDateField(
                label: String(localized: "plans.expense.field.date"),
                date: $model.date
            )
            if model.needsConversion {
                PlansInfoBlock(text: String(localized: "plans.expense.info"))
            }
        }
        .task {
            model.attach(environment)
        }
    }
}

#Preview {
    ExpenseEditorView(
        plan: PlanDTO(id: UUID(), title: "Lisbon in October", type: .trip, targetAmount: 5000, currency: "USD")
    )
    .environment(AppEnvironment.preview())
}
