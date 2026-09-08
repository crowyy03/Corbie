import CorbieCore
import SwiftUI

struct QuestionDayView: View {
    @Environment(\.palette) private var palette
    let question: DailyQuestionDTO

    @Environment(AppEnvironment.self) private var environment

    private let copy = QuestionCopy()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                    Text(copy.day(of: question))
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                    Text(copy.text(of: question) ?? question.questionId)
                        .corbieScreenTitle()
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                if question.answers.isEmpty {
                    Text("question.history.skipped")
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                } else {
                    ForEach(question.answers) { answer in
                        QuestionAnswerCard(
                            name: environment.memberName(id: answer.memberId),
                            slot: environment.memberSlot(id: answer.memberId),
                            answer: answer,
                            stamp: copy.time(of: answer.createdAt),
                            placeholder: String(localized: "question.history.locked")
                        )
                    }
                }
            }
            .padding(CorbieSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(palette.bg)
        .navigationTitle(String(localized: "question.history.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
