import CorbieCore
import SwiftUI

struct GoalDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: GoalDetailViewModel

    init(goalId: UUID) {
        _model = State(initialValue: GoalDetailViewModel(goalId: goalId))
    }

    var body: some View {
        List {
            if let goal = model.goal, let totals = model.totals {
                summarySection(goal: goal, totals: totals)
                noteSection(goal: goal)
                expensesSection(goal: goal)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(CorbieColorPalette.bg)
        .navigationTitle(model.goal?.title ?? "")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            AddToolbarItem {
                model.startAddingExpense()
            }
            ToolbarItem(placement: .topBarTrailing) {
                goalMenu
            }
        }
        .sheet(isPresented: $model.isAddingExpense, onDismiss: { Task { await model.load() } }) {
            if let goal = model.goal {
                ExpenseEditorView(goal: goal)
            }
        }
        .sheet(isPresented: $model.isEditingGoal, onDismiss: { Task { await model.load() } }) {
            GoalEditorView(goal: model.goal)
        }
        .confirmationDialog(
            String(localized: "goals.detail.delete.confirm"),
            isPresented: $model.isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(String(localized: "common.action.delete"), role: .destructive) {
                Task {
                    if await model.deleteGoal() { dismiss() }
                }
            }
        }
        .task {
            model.attach(environment)
            await model.load()
        }
    }

    private var goalMenu: some View {
        Menu {
            Button(String(localized: "goals.detail.action.edit")) {
                model.startEditing()
            }
            if model.goal?.status == .active {
                Button(String(localized: "goals.detail.action.complete")) {
                    Task { await model.setStatus(.completed) }
                }
            }
            if model.goal?.status != .archived {
                Button(String(localized: "goals.detail.action.archive")) {
                    Task { await model.setStatus(.archived) }
                }
            }
            Button(String(localized: "goals.detail.action.delete"), role: .destructive) {
                model.startDeleting()
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(Text("goals.detail.menu.label"))
    }

    private func summarySection(goal: GoalDTO, totals: GoalTotals) -> some View {
        Section {
            GoalSummaryCard(goal: goal, totals: totals)
                .goalsListRow()
        }
    }

    @ViewBuilder
    private func noteSection(goal: GoalDTO) -> some View {
        if let note = goal.note, note.isEmpty == false {
            Section {
                Card {
                    Text(note)
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .goalsListRow()
            } header: {
                SectionCaps(text: String(localized: "goals.detail.note"))
                    .goalsListRow()
            }
        }
    }

    @ViewBuilder
    private func expensesSection(goal: GoalDTO) -> some View {
        Section {
            if model.expenses.isEmpty {
                EmptyState(
                    systemImage: "creditcard",
                    title: String(localized: "goals.detail.expenses.empty"),
                    monoNote: String(localized: "goals.detail.expenses.note"),
                    cta: EmptyStateAction(title: String(localized: "goals.detail.action.addexpense")) {
                        model.startAddingExpense()
                    }
                )
                .padding(.vertical, CorbieSpacing.l)
                .goalsListRow()
            } else {
                ForEach(model.expenses) { expense in
                    GoalExpenseRow(
                        expense: expense,
                        goalCurrency: goal.currency,
                        memberColor: environment.memberColor(id: expense.addedByMemberId),
                        memberName: environment.memberName(id: expense.addedByMemberId)
                    )
                    .goalsListRow()
                }
                .onDelete { offsets in
                    Task { await model.deleteExpenses(at: offsets) }
                }
            }
        } header: {
            SectionCaps(text: String(localized: "goals.detail.expenses"))
                .goalsListRow()
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        GoalDetailView(goalId: UUID())
    }
    .environment(AppEnvironment.preview())
}
#endif
