import CorbieCore
import SwiftUI

struct UsView: View {
    enum Destination: Hashable {
        case capsules(startsWithEditor: Bool)
        case votes(startsWithEditor: Bool)
    }

    @Environment(AppState.self) private var appState
    @State private var destination: Destination?
    @State private var isAddPresented = false

    var body: some View {
        UsHubView()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                AddToolbarItem {
                    isAddPresented = true
                }
            }
            .confirmationDialog(
                String(localized: "us.add.title"),
                isPresented: $isAddPresented,
                titleVisibility: .visible
            ) {
                Button("capsules.action.new") {
                    destination = .capsules(startsWithEditor: true)
                }
                Button("votes.action.new") {
                    destination = .votes(startsWithEditor: true)
                }
                Button("common.action.cancel", role: .cancel) {}
            }
            .navigationDestination(item: $destination) { destination in
                switch destination {
                case let .capsules(startsWithEditor):
                    CapsulesView(startsWithEditor: startsWithEditor)
                case let .votes(startsWithEditor):
                    VotesView(startsWithEditor: startsWithEditor)
                }
            }
            .onChange(of: appState.route, initial: true) { _, route in
                consume(route)
            }
    }

    private func consume(_ route: Route?) {
        switch route {
        case .capsules:
            destination = .capsules(startsWithEditor: false)
            appState.route = nil
        case .votes:
            destination = .votes(startsWithEditor: false)
            appState.route = nil
        default:
            break
        }
    }
}

#Preview {
    NavigationStack {
        UsView()
    }
    .environment(AppState())
    .environment(AppEnvironment.preview())
}
