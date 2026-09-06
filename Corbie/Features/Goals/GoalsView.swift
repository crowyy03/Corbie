import CorbieCore
import SwiftUI

struct GoalsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppState.self) private var appState
    @State private var model = GoalsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                goalsContent
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.top, CorbieSpacing.s)
            .padding(.bottom, CorbieSpacing.xxl)
        }
        .background(CorbieColorPalette.bg)
        .navigationTitle(String(localized: "tab.goals.title"))
        .toolbar {
            AddToolbarItem { model.startCreate() }
            UsPillToolbarItem()
        }
        .refreshable {
            await model.load()
        }
        .task(id: environment.space?.id) {
            model.attach(environment)
            await model.load()
            model.consume(route: appState.route, in: appState)
        }
        .onChange(of: appState.route) {
            model.consume(route: appState.route, in: appState)
        }
        .onChange(of: model.openGoal) { _, reference in
            guard reference == nil else { return }
            Task { await model.load() }
        }
        .sheet(isPresented: $model.isCreating, onDismiss: { Task { await model.load() } }) {
            GoalEditorView(goal: nil)
        }
        .navigationDestination(item: $model.openGoal) { reference in
            GoalDetailView(goalId: reference.id)
        }
    }

    @ViewBuilder
    private var goalsContent: some View {
        if model.isLoaded {
            if model.goals.isEmpty {
                EmptyState(
                    systemImage: "flag",
                    title: String(localized: "goals.empty.title"),
                    monoNote: String(localized: "goals.empty.note"),
                    cta: EmptyStateAction(title: String(localized: "goals.empty.action")) {
                        model.startCreate()
                    }
                )
                .padding(.top, CorbieSpacing.xxl)
            } else {
                LazyVStack(alignment: .leading, spacing: CorbieSpacing.m) {
                    if model.activeGoals.isEmpty == false {
                        SectionCaps(text: String(localized: "goals.section.active"))
                        ForEach(model.activeGoals) { goal in
                            goalRow(goal)
                        }
                    }
                    if model.completedGoals.isEmpty == false {
                        SectionCaps(text: String(localized: "goals.section.completed"))
                            .padding(.top, CorbieSpacing.xs)
                        ForEach(model.completedGoals) { goal in
                            goalRow(goal)
                        }
                    }
                }
            }
        }
    }

    private func goalRow(_ goal: GoalDTO) -> some View {
        Button {
            model.open(goal: goal)
        } label: {
            GoalCard(goal: goal)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        GoalsView()
    }
    .environment(AppState())
    .environment(AppEnvironment.preview())
}
#endif
