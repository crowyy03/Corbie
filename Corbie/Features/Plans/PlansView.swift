import CorbieCore
import SwiftUI

struct PlansView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppState.self) private var appState
    @State private var model = PlansViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                SegmentedPicker(selection: $model.segment, options: PlansViewModel.Segment.allCases) { segment in
                    PlansCopy.text(segment.titleKey)
                }
                segmentContent
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.top, CorbieSpacing.s)
            .padding(.bottom, CorbieSpacing.xxl)
        }
        .background(CorbieColorPalette.bg)
        .navigationTitle(String(localized: "tab.plans.title"))
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
        .onChange(of: model.openPlan) { _, reference in
            guard reference == nil else { return }
            Task { await model.load() }
        }
        .onChange(of: model.openList) { _, reference in
            guard reference == nil else { return }
            Task { await model.load() }
        }
        .sheet(item: $model.sheet, onDismiss: { Task { await model.load() } }) { sheet in
            switch sheet {
            case .newPlan:
                PlanEditorView(plan: nil)
            case .newList:
                ListEditorView(list: nil)
            }
        }
        .navigationDestination(item: $model.openPlan) { reference in
            PlanDetailView(planId: reference.id)
        }
        .navigationDestination(item: $model.openList) { reference in
            ListDetailView(listId: reference.id)
        }
    }

    @ViewBuilder
    private var segmentContent: some View {
        if model.isLoaded {
            switch model.segment {
            case .big:
                plansContent
            case .lists:
                listsContent
            }
        }
    }

    @ViewBuilder
    private var plansContent: some View {
        if model.plans.isEmpty {
            EmptyState(
                systemImage: "flag",
                title: String(localized: "plans.empty.title"),
                monoNote: String(localized: "plans.empty.note"),
                cta: EmptyStateAction(title: String(localized: "plans.empty.action")) {
                    model.startCreate()
                }
            )
            .padding(.top, CorbieSpacing.xxl)
        } else {
            LazyVStack(alignment: .leading, spacing: CorbieSpacing.m) {
                ForEach(model.activePlans) { plan in
                    planRow(plan)
                }
                if model.completedPlans.isEmpty == false {
                    SectionCaps(text: String(localized: "plans.section.completed"))
                        .padding(.top, CorbieSpacing.xs)
                    ForEach(model.completedPlans) { plan in
                        planRow(plan)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var listsContent: some View {
        if model.lists.isEmpty {
            EmptyState(
                systemImage: "checklist",
                title: String(localized: "lists.empty.title"),
                monoNote: String(localized: "lists.empty.note"),
                cta: EmptyStateAction(title: String(localized: "lists.empty.action")) {
                    model.startCreate()
                }
            )
            .padding(.top, CorbieSpacing.xxl)
        } else {
            LazyVStack(alignment: .leading, spacing: CorbieSpacing.m) {
                ForEach(model.lists) { list in
                    Button {
                        model.open(list: list)
                    } label: {
                        ChecklistCard(list: list)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    private func planRow(_ plan: PlanDTO) -> some View {
        Button {
            model.open(plan: plan)
        } label: {
            PlanCard(plan: plan)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PlansView()
    }
    .environment(AppState())
    .environment(AppEnvironment.preview())
}
#endif
