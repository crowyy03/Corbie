import SwiftUI

enum UsDestination: Hashable {
    case capsules(startsWithEditor: Bool)
    case votes(startsWithEditor: Bool)
    case people
    case person(UUID)
    case questions
    case settings
}

private struct UsDestinationsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationDestination(for: UsDestination.self) { destination in
            switch destination {
            case let .capsules(startsWithEditor):
                CapsulesView(startsWithEditor: startsWithEditor)
            case let .votes(startsWithEditor):
                VotesView(startsWithEditor: startsWithEditor)
            case .people:
                PeopleView()
            case let .person(id):
                PersonDetailView(personId: id)
            case .questions:
                QuestionHistoryView()
            case .settings:
                SettingsView()
            }
        }
    }
}

extension View {
    func usDestinations() -> some View {
        modifier(UsDestinationsModifier())
    }
}
