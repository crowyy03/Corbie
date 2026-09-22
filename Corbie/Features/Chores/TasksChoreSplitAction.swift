import CorbieCore
import SwiftUI

struct TasksChoreSplitAction: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var model = ChoreSplitOfferModel()
    @State private var isFlowPresented = false

    var body: some View {
        VStack(spacing: 0) {
            if model.isOffered {
                SecondaryButton(title: String(localized: "tasks.empty.chores")) {
                    isFlowPresented = true
                }
                .padding(.horizontal, CorbieSpacing.xl)
                .padding(.top, CorbieSpacing.s)
            }
        }
        .task {
            model.attach(environment)
            await model.load()
        }
        .sheet(isPresented: $isFlowPresented, onDismiss: { Task { await model.load() } }) {
            ChoreFlowSheet()
        }
    }
}
