import CorbieCore
import SwiftUI

struct ExpenseEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: ExpenseEditorViewModel

    init(goal: GoalDTO) {
        _model = State(initialValue: ExpenseEditorViewModel(goal: goal))
    }

    var body: some View {
        GoalsEditorScaffold(
            title: String(localized: "goals.expense.title"),
            saveTitle: String(localized: "common.action.save"),
            canSave: model.canSave,
            onCancel: { dismiss() },
            onSave: {
                Task {
                    if await model.save() { dismiss() }
                }
            }
        ) {
            GoalsAmountField(
                label: String(localized: "goals.expense.field.amount"),
                amount: $model.amount
            )
            GoalsCurrencyField(
                label: String(localized: "goals.expense.field.currency"),
                currencies: model.currencies,
                selection: $model.currency
            )
            GoalsNoteField(
                label: String(localized: "goals.expense.field.note"),
                placeholder: String(localized: "goals.expense.field.note.placeholder"),
                text: $model.note
            )
            GoalsDateField(
                label: String(localized: "goals.expense.field.date"),
                date: $model.date
            )
            if model.needsConversion {
                GoalsInfoBlock(text: String(localized: "goals.expense.info"))
            }
        }
        .task {
            model.attach(environment)
        }
    }
}

#if DEBUG
#Preview {
    ExpenseEditorView(
        goal: GoalDTO(id: UUID(), title: "Lisbon in October", type: .trip, targetAmount: 5000, currency: "USD")
    )
    .environment(AppEnvironment.preview())
}
#endif
