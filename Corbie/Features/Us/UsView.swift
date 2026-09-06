import CorbieCore
import SwiftUI

struct UsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()
    @State private var isAddPresented = false

    var body: some View {
        NavigationStack(path: $path) {
            UsHubView()
                .paywallBanner()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(Text("common.action.close"))
                    }
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
                        path.append(UsDestination.capsules(startsWithEditor: true))
                    }
                    Button("votes.action.new") {
                        path.append(UsDestination.votes(startsWithEditor: true))
                    }
                    Button("common.action.cancel", role: .cancel) {}
                }
                .usDestinations()
        }
        .onChange(of: appState.route, initial: true) { _, route in
            consume(route)
        }
    }

    private func consume(_ route: Route?) {
        let destination: UsDestination
        switch route {
        case .capsules:
            destination = .capsules(startsWithEditor: false)
        case .votes:
            destination = .votes(startsWithEditor: false)
        case .people:
            destination = .people
        case let .person(id):
            destination = .person(id)
        default:
            return
        }
        path = NavigationPath([destination])
        appState.route = nil
    }
}

#if DEBUG
#Preview {
    UsView()
        .environment(AppState())
        .environment(AppEnvironment.preview())
}
#endif
