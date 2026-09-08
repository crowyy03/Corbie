import CorbieCore
import SwiftUI

struct TasksChoreSplitAction: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var isOffered = false
    @State private var isFlowPresented = false

    var body: some View {
        Group {
            if isOffered {
                SecondaryButton(title: String(localized: "tasks.empty.chores")) {
                    isFlowPresented = true
                }
                .padding(.horizontal, CorbieSpacing.xl)
                .padding(.top, CorbieSpacing.s)
            }
        }
        .task { await load() }
        .sheet(isPresented: $isFlowPresented, onDismiss: { Task { await load() } }) {
            ChoreFlowSheet()
        }
    }

    private func load() async {
        guard let space = environment.space else {
            isOffered = false
            return
        }
        do {
            let sets = try await environment.repositories.chores.history(
                spaceId: space.id,
                viewerMemberId: environment.currentMember?.id
            )
            isOffered = sets.contains { $0.status == .applied } == false
        } catch {
            environment.report(error)
        }
    }
}
