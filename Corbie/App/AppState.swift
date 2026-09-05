import Observation
import SwiftUI

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

    enum ColorSchemePreference: String {
        case system
        case light
        case dark

        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    var selectedTab: Tab = .tasks
    var isUsHubPresented = false
    var colorSchemePreference: ColorSchemePreference = .system
    var route: Route?

    func open(_ route: Route?) {
        guard let route else { return }
        self.route = route
        isUsHubPresented = false
        selectedTab = Self.tab(for: route)
    }

    private static func tab(for route: Route) -> Tab {
        switch route {
        case .tasks: .tasks
        case .calendar: .calendar
        case .wishes: .wishes
        case .plans, .plan: .plans
        case .capsules, .votes, .join: .us
        }
    }
}
