import Observation

@MainActor
@Observable
final class AppState {
    enum Tab: String {
        case tasks
        case calendar
        case wishes
        case plans
        case us
    }

    var selectedTab: Tab = .tasks
    var isUsHubPresented = false
    var route: Route?

    func open(_ route: Route?) {
        guard let route else { return }
        self.route = route
        isUsHubPresented = false
        selectedTab = Self.tab(for: route)
    }

    private static func tab(for route: Route) -> Tab {
        switch route {
        case .tasks, .task: .tasks
        case .calendar: .calendar
        case .wishes: .wishes
        case .plans, .plan: .plans
        case .capsules, .votes, .people, .person, .join: .us
        }
    }
}
