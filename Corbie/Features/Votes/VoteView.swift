import CorbieCore
import SwiftUI

struct VoteView: View {
    @Environment(\.palette) private var palette

    private let onAnswered: (VoteDTO) -> Void

    @Environment(AppEnvironment.self) private var environment
    @State private var model: VoteViewModel

    init(vote: VoteDTO, onAnswered: @escaping (VoteDTO) -> Void) {
        self.onAnswered = onAnswered
        _model = State(initialValue: VoteViewModel(vote: vote))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                Text(model.vote.question)
                    .corbieScreenTitle()
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                options
                outcome
                if model.outcome.showsResults == false {
                    PrimaryButton(
                        title: model.hasAnswered
                            ? String(localized: "votes.detail.change")
                            : String(localized: "votes.detail.answer")
                    ) {
                        submit()
                    }
                    .disabled(model.canSubmit == false)
                    .accessibilityIdentifier("vote.submit")
                }
            }
            .padding(CorbieSpacing.l)
        }
        .background(palette.bg)
        .navigationTitle(String(localized: "votes.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            model.attach(environment)
            await model.refresh()
        }
    }

    private var options: some View {
        VStack(spacing: CorbieSpacing.xs) {
            ForEach(Array(model.vote.options.enumerated()), id: \.offset) { index, option in
                Button {
                    model.toggle(index)
                } label: {
                    optionCard(index: index, option: option)
                }
                .buttonStyle(.plain)
                .disabled(model.outcome.showsResults)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(
                    model.selection.contains(index) ? [.isButton, .isSelected] : .isButton
                )
            }
        }
    }

    private func optionCard(index: Int, option: String) -> some View {
        let isPicked = model.selection.contains(index)
        let isShared = model.partnerVisibleOptions.contains(index)
        return Card(isHighlighted: isPicked && isShared) {
            HStack(spacing: CorbieSpacing.s) {
                Image(systemName: indicator(isPicked: isPicked))
                    .foregroundStyle(isPicked ? palette.accent : palette.text2)
                    .accessibilityHidden(true)
                Text(option)
                    .corbieBody()
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isPicked {
                    MemberDot(
                        slot: environment.memberSlot(id: environment.currentMember?.id),
                        accessibilityLabel: String(localized: "votes.detail.yours")
                    )
                }
                if isShared {
                    MemberDot(
                        slot: environment.memberSlot(id: environment.partner?.id),
                        accessibilityLabel: environment.partnerName
                    )
                }
            }
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
        }
    }

    private var outcome: some View {
        Card {
            VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                Text(outcomeTitle)
                    .corbieBody()
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.text)
                Text(outcomeNote)
                    .corbieMono()
                    .foregroundStyle(palette.text2)
                    .multilineTextAlignment(.leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var outcomeTitle: String {
        switch model.outcome {
        case .needsYourAnswer:
            return String(localized: "votes.detail.hidden.title")
        case .waitingForPartner:
            return String(localized: "votes.detail.waiting.title")
        case let .match(indexes):
            return String(
                format: String(localized: "votes.detail.match.title"),
                titles(of: indexes).formatted(.list(type: .and))
            )
        case .mismatch:
            return String(localized: "votes.detail.mismatch.title")
        case .noMatch:
            return String(localized: "votes.detail.nomatch.title")
        }
    }

    private var outcomeNote: String {
        switch model.outcome {
        case .needsYourAnswer:
            return String(localized: "votes.detail.hidden.note")
        case .waitingForPartner:
            return String(format: String(localized: "votes.detail.waiting.note"), environment.partnerName)
        case .match:
            return String(localized: "votes.detail.match.note")
        case .mismatch:
            return String(format: String(localized: "votes.detail.mismatch.note"), environment.partnerName)
        case .noMatch:
            return String(localized: "votes.detail.nomatch.note")
        }
    }

    private func indicator(isPicked: Bool) -> String {
        if model.vote.mode == .single {
            return isPicked ? "largecircle.fill.circle" : "circle"
        }
        return isPicked ? "checkmark.circle.fill" : "circle"
    }

    private func titles(of indexes: [Int]) -> [String] {
        indexes.compactMap { index in
            model.vote.options.indices.contains(index) ? model.vote.options[index] : nil
        }
    }

    private func submit() {
        Task {
            guard let updated = await model.submit() else { return }
            onAnswered(updated)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        VoteView(
            vote: VoteDTO(
                id: UUID(),
                question: "Where do we eat on Friday",
                options: ["Out", "Delivery", "Cook at home"],
                mode: .multi
            )
        ) { _ in }
    }
    .environment(AppEnvironment.preview())
}
#endif
