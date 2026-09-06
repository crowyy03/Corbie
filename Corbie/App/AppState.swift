import Observation

@MainActor
@Observable
final class AppState {
    enum Tab: String {
        case today
        case tasks
        case calendar
        case wishes
        case goals
    }

    var selectedTab: Tab = .today
    var isUsHubPresented = false
    var route: Route?

    func open(_ route: Route?) {
        guard let route else { return }
        self.route = route
        if let tab = Self.tab(for: route) {
            isUsHubPresented = false
            selectedTab = tab
        } else {
            isUsHubPresented = Self.opensUsHub(route)
        }
    }

    private static func tab(for route: Route) -> Tab? {
        switch route {
        case .today: .today
        case .tasks, .task: .tasks
        case .calendar: .calendar
        case .wishes: .wishes
        case .goals, .goal: .goals
        case .capsules, .votes, .people, .person, .us, .join: nil
        }
    }

    private static func opensUsHub(_ route: Route) -> Bool {
        switch route {
        case .capsules, .votes, .people, .person, .us: true
        default: false
        }
    }
}
