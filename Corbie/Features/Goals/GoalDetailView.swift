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
        @Bindable var model = model

        return List {
            if let goal = model.goal, let totals = model.totals {
                progressSection(goal: goal, totals: totals)
                expensesSection(goal: goal)
                stepsSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(CorbieColorPalette.bg)
        .navigationTitle(model.goal?.title ?? "")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if model.isReadOnly == false {
                AddToolbarItem {
                    model.startAddingExpense()
                }
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
        .sheet(item: $model.editedStep, onDismiss: { Task { await model.load() } }) { step in
            GoalStepEditorView(step: step)
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
            if model.isReadOnly == false {
                Button(String(localized: "goals.detail.action.edit")) {
                    model.startEditing()
                }
                if model.goal?.status == .active {
                    Button(String(localized: "goals.detail.action.complete")) {
                        Task { _ = await model.setStatus(.completed) }
                    }
                    Button(String(localized: "goals.detail.action.archive")) {
                        Task {
                            if await model.setStatus(.archived) { dismiss() }
                        }
                    }
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

    private func progressSection(goal: GoalDTO, totals: GoalTotals) -> some View {
        Section {
            GoalSummaryCard(goal: goal, totals: totals)
                .goalsListRow()
            if let note = goal.note, note.isEmpty == false {
                Card {
                    Text(note)
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .goalsListRow()
            }
        } header: {
            GoalsSectionHeader(text: String(localized: "goals.detail.progress"))
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
                    cta: model.isReadOnly
                        ? nil
                        : EmptyStateAction(title: String(localized: "goals.detail.action.addexpense")) {
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
            GoalsSectionHeader(text: String(localized: "goals.detail.expenses"))
        }
    }

    private var stepsSection: some View {
        @Bindable var model = model

        return Section {
            ForEach(model.steps) { step in
                GoalStepRow(
                    step: step,
                    due: goalStepDue(for: step, now: Date()),
                    assigneeColor: step.assigneeMemberId.map { environment.memberColor(id: $0) },
                    assigneeName: step.assigneeMemberId.map { environment.memberName(id: $0) },
                    isReadOnly: model.isReadOnly,
                    toggle: { Task { await model.toggleStep(step) } },
                    openEditor: { model.startEditingStep(step) }
                )
                .goalsListRow()
            }
            .onDelete { offsets in
                Task { await model.deleteSteps(at: offsets) }
            }
            .onMove { offsets, destination in
                Task { await model.moveSteps(from: offsets, to: destination) }
            }
            if model.isReadOnly == false {
                GoalStepComposer(title: $model.stepTitle, canAdd: model.canAddStep) {
                    Task { await model.addStep() }
                }
                .goalsListRow()
            }
            if model.steps.isEmpty {
                Text("goals.detail.steps.hint")
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
                    .goalsListRow()
            }
        } header: {
            GoalsSectionHeader(text: String(localized: "goals.detail.steps"))
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
