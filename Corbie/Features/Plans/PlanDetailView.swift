import CorbieCore
import SwiftUI

struct PlanDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: PlanDetailViewModel

    init(planId: UUID) {
        _model = State(initialValue: PlanDetailViewModel(planId: planId))
    }

    var body: some View {
        List {
            if let plan = model.plan, let totals = model.totals {
                summarySection(plan: plan, totals: totals)
                noteSection(plan: plan)
                expensesSection(plan: plan)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(CorbieColorPalette.bg)
        .navigationTitle(model.plan?.title ?? "")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            AddToolbarItem {
                model.startAddingExpense()
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
            Button(String(localized: "plans.detail.action.edit")) {
                model.startEditing()
            }
            if model.plan?.status == .active {
                Button(String(localized: "plans.detail.action.complete")) {
                    Task { await model.setStatus(.completed) }
                }
            }
            if model.plan?.status != .archived {
                Button(String(localized: "plans.detail.action.archive")) {
                    Task { await model.setStatus(.archived) }
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

    private func summarySection(plan: PlanDTO, totals: PlanTotals) -> some View {
        Section {
            PlanSummaryCard(plan: plan, totals: totals)
                .plansListRow()
        }
    }

    @ViewBuilder
    private func noteSection(plan: PlanDTO) -> some View {
        if let note = plan.note, note.isEmpty == false {
            Section {
                Card {
                    Text(note)
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .plansListRow()
            } header: {
                SectionCaps(text: String(localized: "plans.detail.note"))
                    .plansListRow()
            }
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
                    cta: EmptyStateAction(title: String(localized: "plans.detail.action.addexpense")) {
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
                        memberColor: environment.memberColor(id: expense.addedByMemberId),
                        memberName: environment.memberName(id: expense.addedByMemberId)
                    )
                    .plansListRow()
                }
                .onDelete { offsets in
                    Task { await model.deleteExpenses(at: offsets) }
                }
            }
        } header: {
            SectionCaps(text: String(localized: "plans.detail.expenses"))
                .plansListRow()
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
