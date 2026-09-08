import CorbieCore
import SwiftUI

struct TodayQuestionCard: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    @State private var model = TodayQuestionModel()
    @State private var wantsAnswering = false

    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            if model.isVisible {
                card
            }
        }
        .task { await model.start(environment) }
        .onDisappear { model.stopObserving() }
        .onChange(of: environment.session) {
            Task { await model.open() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await model.open() }
        }
        .onChange(of: appState.route, initial: true) { _, route in
            guard route == .question else { return }
            appState.route = nil
            wantsAnswering = true
        }
        .sheet(isPresented: sheetBinding) {
            questionSheet
        }
    }

    private var sheetBinding: Binding<Bool> {
        Binding(
            get: { wantsAnswering && model.isVisible },
            set: { wantsAnswering = $0 }
        )
    }

    @ViewBuilder private var questionSheet: some View {
        if let question = model.question, let text = model.text {
            QuestionView(question: question, text: text) { updated in
                model.apply(updated)
            }
        }
    }

    @ViewBuilder private var card: some View {
        SectionCaps(text: String(localized: "today.block.question"))
        Card {
            VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                Text(model.text ?? "")
                    .corbieScreenTitle()
                    .foregroundStyle(CorbieColorPalette.text)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                status
                PrimaryButton(title: callToAction) {
                    wantsAnswering = true
                }
            }
        }
    }

    private var status: some View {
        HStack(alignment: .top, spacing: CorbieSpacing.m) {
            column(memberId: environment.currentMember?.id, isViewer: true)
            if environment.isPaired {
                column(memberId: environment.partner?.id, isViewer: false)
            }
        }
    }

    private func column(memberId: UUID?, isViewer: Bool) -> some View {
        let answered = model.question?.hasAnswered(memberId) ?? false
        return Text(statusLine(memberId: memberId, isViewer: isViewer, answered: answered))
            .corbieCaption()
            .fontWeight(answered ? .semibold : .regular)
            .foregroundStyle(answered ? environment.memberColor(id: memberId) : CorbieColorPalette.text2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusLine(memberId: UUID?, isViewer: Bool, answered: Bool) -> String {
        if isViewer {
            return String(localized: answered ? "question.status.you.answered" : "question.status.you.writing")
        }
        let name = environment.partnerName
        let key: String.LocalizationValue = answered ? "question.status.answered" : "question.status.writing"
        return String.localizedStringWithFormat(String(localized: key), name)
    }

    private var callToAction: String {
        if model.hasAnswered == false { return String(localized: "question.action.answer") }
        if model.question?.isRevealed == true { return String(localized: "question.action.see") }
        return String(localized: "question.action.yours")
    }
}
