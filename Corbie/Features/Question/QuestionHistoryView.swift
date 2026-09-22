import CorbieCore
import SwiftUI

struct QuestionHistoryView: View {
    @Environment(\.palette) private var palette
    @Environment(AppEnvironment.self) private var environment
    @State private var model = QuestionHistoryViewModel()

    private let copy = QuestionCopy()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                if model.days.isEmpty {
                    if model.hasLoaded {
                        empty
                    }
                } else {
                    ForEach(model.days) { day in
                        NavigationLink {
                            QuestionDayView(question: day)
                        } label: {
                            row(day)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                    }
                }
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.vertical, CorbieSpacing.m)
        }
        .background(palette.bg)
        .navigationTitle(String(localized: "question.history.title"))
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $model.search, prompt: Text("question.history.search"))
        .task(id: model.search) {
            model.reloadOnStoreChanges(environment)
            await model.load(environment)
        }
    }

    private var empty: some View {
        EmptyState(
            systemImage: "text.bubble",
            title: String(localized: "question.history.empty.title"),
            monoNote: String(localized: "question.history.empty.note")
        )
        .padding(.top, CorbieSpacing.xxl)
    }

    private func row(_ day: DailyQuestionDTO) -> some View {
        Card {
            VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                HStack(alignment: .center, spacing: CorbieSpacing.xs) {
                    Text(copy.day(of: day))
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                    Spacer(minLength: 0)
                    if environment.questionStatus(of: day)?.showsHistoryDot == true {
                        unreadDot
                    }
                }
                Text(copy.text(of: day) ?? day.questionId)
                    .corbieBody()
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if day.answers.isEmpty {
                    Text("question.history.skipped")
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                } else {
                    ForEach(day.answers) { answer in
                        answerLine(answer)
                    }
                }
            }
        }
    }

    private var unreadDot: some View {
        Circle()
            .fill(palette.accent)
            .frame(width: CorbieSpacing.xs, height: CorbieSpacing.xs)
            .accessibilityElement()
            .accessibilityLabel(Text(QuestionCopy.waitingDotLabel(partnerName: environment.partnerName)))
    }

    @ViewBuilder private func answerLine(_ answer: QuestionAnswerDTO) -> some View {
        HStack(alignment: .top, spacing: CorbieSpacing.xs) {
            MemberDot(slot: environment.memberSlot(id: answer.memberId))
                .padding(.top, CorbieSpacing.xxs)
            Text(answer.text ?? String(localized: "question.history.locked"))
                .corbieCaption()
                .foregroundStyle(answer.isHidden ? palette.text2 : palette.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }
}
