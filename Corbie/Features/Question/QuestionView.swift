import CorbieCore
import SwiftUI

struct QuestionView: View {
    @Environment(\.palette) private var palette
    private let onChanged: (DailyQuestionDTO) -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: QuestionViewModel

    private let copy = QuestionCopy()

    init(
        question: DailyQuestionDTO,
        text: String,
        onChanged: @escaping (DailyQuestionDTO) -> Void
    ) {
        self.onChanged = onChanged
        _model = State(initialValue: QuestionViewModel(question: question, text: text))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    Text(model.text)
                        .corbieScreenTitle()
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if model.isWriting {
                        editor
                    } else {
                        own
                    }
                    partner
                }
                .padding(CorbieSpacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(palette.bg)
            .paywallBanner()
            .navigationTitle(String(localized: "question.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.action.done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            model.onChanged = onChanged
            await model.attach(environment)
        }
        .onDisappear { model.detach() }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.m) {
            FieldRow(
                label: String(localized: "question.editor.label"),
                hint: model.showsCounter
                    ? String.localizedStringWithFormat(
                        String(localized: "question.editor.left"),
                        model.charactersLeft
                    )
                    : nil
            ) {
                TextEditor(text: $model.draft)
                    .corbieBody()
                    .foregroundStyle(palette.text)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 160)
                    .padding(CorbieSpacing.xs)
                    .corbieFieldBox()
                    .disabled(environment.premiumGate.isReadOnly)
                    .accessibilityLabel(Text("question.editor.label"))
            }
            PrimaryButton(title: String(localized: "common.action.save")) {
                Task { await model.save() }
            }
            .disabled(model.canSave == false)
        }
    }

    private var own: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            QuestionAnswerCard(
                name: String(localized: "member.name.you"),
                slot: environment.memberSlot(id: environment.currentMember?.id),
                answer: model.ownAnswer,
                stamp: copy.time(of: model.ownAnswer?.createdAt),
                placeholder: nil
            )
            if model.canEditOwnAnswer {
                SecondaryButton(title: String(localized: "question.action.edit")) {
                    model.startEditing()
                }
            }
        }
    }

    private var partner: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            QuestionAnswerCard(
                name: environment.partnerName,
                slot: environment.memberSlot(id: environment.partner?.id),
                answer: model.isRevealed ? model.partnerAnswer : nil,
                stamp: model.isRevealed ? copy.time(of: model.partnerAnswer?.createdAt) : nil,
                placeholder: model.isRevealed
                    ? nil
                    : String.localizedStringWithFormat(
                        String(localized: "question.hidden"),
                        environment.partnerName
                    )
            )
            if environment.isPaired, model.isRevealed == false, model.ownAnswer != nil {
                SecondaryButton(title: String(localized: "question.action.nudge")) {
                    Task { await model.nudge() }
                }
                .disabled(model.canNudge == false)
            }
        }
    }
}

#if DEBUG
#Preview {
    QuestionView(
        question: DailyQuestionDTO(id: UUID(), dayKey: "2026-09-08"),
        text: "What made you laugh today"
    ) { _ in }
        .environment(AppEnvironment.previewSignedIn())
}
#endif
