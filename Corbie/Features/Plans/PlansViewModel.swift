import CorbieCore
import Observation
import SwiftUI

enum PlansCopy {
    static func text(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }
}

@MainActor
@Observable
final class PlansViewModel {
    enum Segment: String, CaseIterable, Hashable {
        case big
        case lists

        var titleKey: String { "plans.segment." + rawValue }
    }

    enum Sheet: String, Identifiable, Hashable {
        case newPlan
        case newList

        var id: String { rawValue }
    }

    var segment: Segment = .big
    var sheet: Sheet?
    var openPlan: PlanReference?
    var openList: ChecklistReference?
    private(set) var plans: [PlanDTO] = []
    private(set) var lists: [ChecklistListDTO] = []
    private(set) var isLoaded = false

    @ObservationIgnored private var environment: AppEnvironment?

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
    }

    var activePlans: [PlanDTO] {
        plans.filter { $0.status == .active }
    }

    var completedPlans: [PlanDTO] {
        plans.filter { $0.status == .completed }
    }

    func load() async {
        guard let environment, let space = environment.space else {
            isLoaded = true
            return
        }
        do {
            plans = try await environment.repositories.plans.plans(
                spaceId: space.id,
                statuses: [.active, .completed]
            )
            lists = try await loadLists(space: space, environment: environment)
        } catch {
            environment.report(error)
        }
        isLoaded = true
    }

    func startCreate() {
        guard let environment, environment.premiumGate.require(.create) else { return }
        sheet = segment == .big ? .newPlan : .newList
    }

    func open(plan: PlanDTO) {
        openPlan = PlanReference(id: plan.id)
    }

    func open(list: ChecklistListDTO) {
        openList = ChecklistReference(id: list.id)
    }

    func consume(route: Route?, in appState: AppState) {
        guard let destination = PlansRoute.destination(for: route) else { return }
        switch destination {
        case .big:
            segment = .big
        case let .plan(identifier):
            segment = .big
            openList = nil
            openPlan = PlanReference(id: identifier)
        }
        appState.route = nil
    }

    private func loadLists(space: SpaceDTO, environment: AppEnvironment) async throws -> [ChecklistListDTO] {
        let stored = try await environment.repositories.lists.lists(spaceId: space.id)
        guard stored.contains(where: \.isPinnedShopping) == false else { return stored }
        _ = try await environment.repositories.lists.pinnedShoppingList(
            spaceId: space.id,
            title: PlansCopy.text("lists.shopping.title"),
            createdByMemberId: environment.currentMember?.id
        )
        return try await environment.repositories.lists.lists(spaceId: space.id)
    }
}
