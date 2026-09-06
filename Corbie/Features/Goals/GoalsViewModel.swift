import CorbieCore
import Observation
import SwiftUI

enum GoalsCopy {
    static func text(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }
}

@MainActor
@Observable
final class GoalsViewModel {
    var isCreating = false
    var openGoal: GoalReference?
    private(set) var goals: [GoalDTO] = []
    private(set) var isLoaded = false

    @ObservationIgnored private var environment: AppEnvironment?

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
    }

    var activeGoals: [GoalDTO] {
        goals.filter { $0.status == .active }
    }

    var completedGoals: [GoalDTO] {
        goals.filter { $0.status == .completed }
    }

    func load() async {
        guard let environment, let space = environment.space else {
            isLoaded = true
            return
        }
        do {
            goals = try await environment.repositories.goals.goals(
                spaceId: space.id,
                statuses: [.active, .completed]
            )
        } catch {
            environment.report(error)
        }
        isLoaded = true
    }

    func startCreate() {
        guard let environment, environment.premiumGate.require(.create) else { return }
        isCreating = true
    }

    func open(goal: GoalDTO) {
        openGoal = GoalReference(id: goal.id)
    }

    func consume(route: Route?, in appState: AppState) {
        guard let destination = GoalsRoute.destination(for: route) else { return }
        switch destination {
        case .list:
            openGoal = nil
        case let .goal(identifier):
            openGoal = GoalReference(id: identifier)
        }
        appState.route = nil
    }
}
