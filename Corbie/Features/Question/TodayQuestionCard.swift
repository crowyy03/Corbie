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
        TodayQuestionFull(text: model.text ?? "", status: fullStatus, callToAction: callToAction) {
            wantsAnswering = true
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

    private var fullStatus: TodayQuestionFullStatus {
        if model.status?.progress == .unanswered(partnerAnswered: true) {
            return .yourTurn(
                line: QuestionCopy.status(.unanswered(partnerAnswered: true), partnerName: environment.partnerName),
                color: memberColor(environment.partner?.id)
            )
        }
        var columns = [column(memberId: environment.currentMember?.id, isViewer: true)]
        if environment.isPaired {
            columns.append(column(memberId: environment.partner?.id, isViewer: false))
        }
        return .columns(columns)
    }

    private func column(memberId: UUID?, isViewer: Bool) -> TodayQuestionColumn {
        let answered = model.question?.hasAnswered(memberId) ?? false
        return TodayQuestionColumn(
            line: statusLine(memberId: memberId, isViewer: isViewer, answered: answered),
            answered: answered,
            color: memberColor(memberId)
        )
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

struct TodayQuestionColumn {
    let line: String
    let answered: Bool
    let color: Color
}

enum TodayQuestionFullStatus {
    case yourTurn(line: String, color: Color)
    case columns([TodayQuestionColumn])
}

struct TodayQuestionFull: View {
    @Environment(\.palette) private var palette

    let text: String
    let status: TodayQuestionFullStatus
    let callToAction: String
    let answer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.m) {
            TodayQuestionTitle(text: text)
            statusView
            PrimaryButton(title: callToAction, action: answer)
        }
    }

    @ViewBuilder private var statusView: some View {
        switch status {
        case let .yourTurn(line, color):
            Text(line)
                .corbieCaption()
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
        case let .columns(columns):
            HStack(alignment: .top, spacing: CorbieSpacing.m) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    Text(column.line)
                        .corbieCaption()
                        .fontWeight(column.answered ? .semibold : .regular)
                        .foregroundStyle(column.answered ? column.color : palette.text2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct TodayQuestionTitle: View {
    static let smallestScale = CorbieFont.bodySize / CorbieFont.screenTitleSize

    static func lineLimit(for size: DynamicTypeSize) -> Int {
        switch size {
        case .xSmall, .small, .medium, .large: return 3
        case .xLarge, .xxLarge, .xxxLarge: return 4
        case .accessibility1: return 5
        default: return 6
        }
    }

    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let text: String

    var body: some View {
        Text(text)
            .corbieScreenTitle()
            .foregroundStyle(palette.text)
            .lineLimit(Self.lineLimit(for: dynamicTypeSize))
            .minimumScaleFactor(Self.smallestScale)
            .truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: true)
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
