import CorbieCore
import SwiftUI

struct PlanDetailView: View {
    @Environment(\.palette) private var palette

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: PlanDetailViewModel

    init(planId: UUID) {
        _model = State(initialValue: PlanDetailViewModel(planId: planId))
    }

    var body: some View {
        @Bindable var model = model

        return List {
            if let plan = model.plan, let totals = model.totals {
                progressSection(plan: plan, totals: totals)
                expensesSection(plan: plan)
                stepsSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(palette.bg)
        .navigationTitle(model.plan?.title ?? "")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if model.isReadOnly == false {
                AddToolbarItem {
                    model.startAddingExpense()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                planMenu
            }
        }
        .sheet(isPresented: $model.isAddingExpense, onDismiss: { Task { await model.load() } }) {
            if let plan = model.plan {
                ExpenseEditorView(plan: plan)
            }
        }
        .sheet(isPresented: $model.isEditingPlan, onDismiss: { Task { await model.load() } }) {
            PlanEditorView(plan: model.plan)
        }
        .sheet(item: $model.editedStep, onDismiss: { Task { await model.load() } }) { step in
            PlanStepEditorView(step: step)
        }
        .confirmationDialog(
            String(localized: "plans.detail.delete.confirm"),
            isPresented: $model.isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(String(localized: "common.action.delete"), role: .destructive) {
                Task {
                    if await model.deletePlan() { dismiss() }
                }
            }
        }
        .task {
            model.attach(environment)
            await model.load()
        }
    }

    private var planMenu: some View {
        Menu {
            if model.isReadOnly == false {
                Button(String(localized: "plans.detail.action.edit")) {
                    model.startEditing()
                }
                if model.plan?.status == .active {
                    Button(String(localized: "plans.detail.action.complete")) {
                        Task { _ = await model.setStatus(.completed) }
                    }
                    Button(String(localized: "plans.detail.action.archive")) {
                        Task {
                            if await model.setStatus(.archived) { dismiss() }
                        }
                    }
                }
            }
            Button(String(localized: "plans.detail.action.delete"), role: .destructive) {
                model.startDeleting()
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(Text("plans.detail.menu.label"))
    }

    private func progressSection(plan: PlanDTO, totals: PlanTotals) -> some View {
        Section {
            PlanSummaryCard(plan: plan, totals: totals)
                .plansListRow()
            if let note = plan.note, note.isEmpty == false {
                Card {
                    Text(note)
                        .corbieBody()
                        .foregroundStyle(palette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .plansListRow()
            }
        } header: {
            PlansSectionHeader(
                text: String(localized: plan.isOpenEnded ? "plans.detail.total" : "plans.detail.progress")
            )
        }
    }

    @ViewBuilder
    private func expensesSection(plan: PlanDTO) -> some View {
        Section {
            if model.expenses.isEmpty {
                EmptyState(
                    systemImage: "creditcard",
                    title: String(localized: "plans.detail.expenses.empty"),
                    monoNote: String(localized: "plans.detail.expenses.note"),
                    cta: model.isReadOnly
                        ? nil
                        : EmptyStateAction(title: String(localized: "plans.detail.action.addexpense")) {
                            model.startAddingExpense()
                        }
                )
                .padding(.vertical, CorbieSpacing.l)
                .plansListRow()
            } else {
                ForEach(model.expenses) { expense in
                    PlanExpenseRow(
                        expense: expense,
                        planCurrency: plan.currency,
                        memberSlot: environment.memberSlot(id: expense.addedByMemberId),
                        memberName: environment.memberName(id: expense.addedByMemberId)
                    )
                    .plansListRow()
                }
                .onDelete { offsets in
                    Task { await model.deleteExpenses(at: offsets) }
                }
            }
        } header: {
            PlansSectionHeader(text: String(localized: "plans.detail.expenses"))
        }
    }

    private var stepsSection: some View {
        @Bindable var model = model

        return Section {
            ForEach(model.steps) { step in
                PlanStepRow(
                    step: step,
                    due: planStepDue(for: step, now: Date()),
                    assigneeSlot: environment.memberSlot(id: step.assigneeMemberId),
                    assigneeName: step.assigneeMemberId.map { environment.memberName(id: $0) },
                    isReadOnly: model.isReadOnly,
                    toggle: { Task { await model.toggleStep(step) } },
                    openEditor: { model.startEditingStep(step) }
                )
                .plansListRow()
            }
            .onDelete { offsets in
                Task { await model.deleteSteps(at: offsets) }
            }
            .onMove { offsets, destination in
                Task { await model.moveSteps(from: offsets, to: destination) }
            }
            if model.isReadOnly == false {
                PlanStepComposer(title: $model.stepTitle, canAdd: model.canAddStep) {
                    Task { await model.addStep() }
                }
                .plansListRow()
            }
            if model.steps.isEmpty {
                Text("plans.detail.steps.hint")
                    .corbieMono()
                    .foregroundStyle(palette.text2)
                    .plansListRow()
            }
        } header: {
            PlansSectionHeader(text: String(localized: "plans.detail.steps"))
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PlanDetailView(planId: UUID())
    }
    .environment(AppEnvironment.preview())
}
#endif
