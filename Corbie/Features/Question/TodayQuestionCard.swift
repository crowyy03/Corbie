import CorbieCore
import SwiftUI

struct TodayQuestionCard: View {
    @Environment(\.palette) private var palette
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var model = TodayQuestionModel()
    @State private var wantsAnswering = false
    @State private var shownLayout = TodayQuestionLayout(questionId: nil, isCompact: false)

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
        .onChange(of: model.layout, initial: true) {
            settleLayout()
        }
        .sheet(isPresented: sheetBinding, onDismiss: settleLayout) {
            questionSheet
        }
    }

    private var sheetBinding: Binding<Bool> {
        Binding(
            get: { wantsAnswering && model.isVisible },
            set: { wantsAnswering = $0 }
        )
    }

    private func settleLayout() {
        let target = model.layout
        guard target != shownLayout else { return }
        guard target.questionId == shownLayout.questionId else {
            shownLayout = target
            return
        }
        guard wantsAnswering == false else { return }
        withAnimation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.25)) {
            shownLayout = target
        }
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
            ZStack(alignment: .topLeading) {
                if shownLayout.isCompact {
                    compact
                        .transition(.opacity)
                } else {
                    full
                        .transition(.opacity)
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: CorbieRadius.card, style: .continuous))
        .gesture(TapGesture().onEnded(openFromCompactCard), including: shownLayout.isCompact ? .all : .subviews)
        .accessibilityElement(children: shownLayout.isCompact ? .combine : .contain)
        .accessibilityAddTraits(shownLayout.isCompact ? .isButton : [])
        .accessibilityAction {
            openFromCompactCard()
        }
    }

    private func openFromCompactCard() {
        guard shownLayout.isCompact else { return }
        wantsAnswering = true
    }

    private var full: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.m) {
            Text(model.text ?? "")
                .corbieScreenTitle()
                .foregroundStyle(palette.text)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
            fullStatus
            PrimaryButton(title: callToAction) {
                wantsAnswering = true
            }
        }
    }

    private var compact: some View {
        HStack(alignment: .center, spacing: CorbieSpacing.s) {
            VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                Text(model.text ?? "")
                    .corbieBody()
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(compactStatus)
                    .corbieCaption()
                    .foregroundStyle(palette.text2)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if model.status?.showsTodayDot == true {
                PulsingRevealDot(label: QuestionCopy.waitingDotLabel(partnerName: environment.partnerName))
                    .transition(.opacity)
            }
        }
    }

    private var compactStatus: String {
        QuestionCopy.status(model.status?.progress ?? .waitingForPartner, partnerName: environment.partnerName)
    }

    @ViewBuilder private var fullStatus: some View {
        if model.status?.progress == .unanswered(partnerAnswered: true) {
            Text(QuestionCopy.status(.unanswered(partnerAnswered: true), partnerName: environment.partnerName))
                .corbieCaption()
                .fontWeight(.semibold)
                .foregroundStyle(memberColor(environment.partner?.id))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top, spacing: CorbieSpacing.m) {
                column(memberId: environment.currentMember?.id, isViewer: true)
                if environment.isPaired {
                    column(memberId: environment.partner?.id, isViewer: false)
                }
            }
        }
    }

    private func column(memberId: UUID?, isViewer: Bool) -> some View {
        let answered = model.question?.hasAnswered(memberId) ?? false
        return Text(statusLine(memberId: memberId, isViewer: isViewer, answered: answered))
            .corbieCaption()
            .fontWeight(answered ? .semibold : .regular)
            .foregroundStyle(answered ? memberColor(memberId) : palette.text2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func memberColor(_ memberId: UUID?) -> Color {
        environment.memberSlot(id: memberId).map(palette.member) ?? palette.text2
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

private struct PulsingRevealDot: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let label: String

    private struct Pulse {
        var dotScale: CGFloat = 1
        var ringScale: CGFloat = 1
        var ringOpacity: Double = 0.5
    }

    var body: some View {
        let accent = palette.accent
        Group {
            if reduceMotion {
                dot(accent)
            } else {
                dot(accent)
                    .keyframeAnimator(initialValue: Pulse(), repeating: true) { content, pulse in
                        content
                            .scaleEffect(pulse.dotScale)
                            .background {
                                Circle()
                                    .stroke(accent, lineWidth: CorbieMetrics.hairline)
                                    .scaleEffect(pulse.ringScale)
                                    .opacity(pulse.ringOpacity)
                            }
                    } keyframes: { _ in
                        KeyframeTrack(\.dotScale) {
                            LinearKeyframe(1.15, duration: 0.8, timingCurve: .easeInOut)
                            LinearKeyframe(1, duration: 0.8, timingCurve: .easeInOut)
                        }
                        KeyframeTrack(\.ringScale) {
                            LinearKeyframe(2.6, duration: 1.6, timingCurve: .easeInOut)
                        }
                        KeyframeTrack(\.ringOpacity) {
                            LinearKeyframe(0, duration: 1.6, timingCurve: .easeInOut)
                        }
                    }
            }
        }
        .frame(width: CorbieSpacing.l, height: CorbieSpacing.l)
        .accessibilityElement()
        .accessibilityLabel(Text(label))
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: CorbieSpacing.xs, height: CorbieSpacing.xs)
    }
}
