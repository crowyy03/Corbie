import CorbieCore
import SwiftUI

struct TodayChoreCard: View {
    @Environment(\.palette) private var palette
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase

    @State private var model = TodayChoreModel()
    @State private var isFlowPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            if model.isVisible {
                card
            }
        }
        .task { await model.start(environment) }
        .onDisappear { model.stopObserving() }
        .onChange(of: environment.session) {
            Task { await model.load() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await model.load() }
        }
        .sheet(isPresented: $isFlowPresented, onDismiss: { Task { await model.load() } }) {
            ChoreFlowSheet()
        }
    }

    @ViewBuilder private var card: some View {
        SectionCaps(text: String(localized: "today.block.chores"))
        Card {
            VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text(title)
                        .corbieBody()
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(note)
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                }
                PrimaryButton(title: action) {
                    isFlowPresented = true
                }
            }
        }
    }

    private var title: String {
        model.state == .readyToReveal
            ? String(localized: "today.chores.ready.title")
            : String(localized: "today.chores.rate.title")
    }

    private var note: String {
        model.state == .readyToReveal
            ? String(localized: "today.chores.ready.note")
            : String(localized: "today.chores.rate.note")
    }

    private var action: String {
        model.state == .readyToReveal
            ? String(localized: "chore.action.reveal")
            : String(localized: "chore.action.rate")
    }
}
