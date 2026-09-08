import CorbieCore
import Foundation

struct QuestionReminderPlan: Equatable {
    let dayKey: String
    let partnerAnswered: Bool
    let viewerAnswered: Bool
}

enum QuestionReminderPlanner {
    static func plan(
        question: DailyQuestionDTO?,
        viewerMemberId: UUID?,
        partnerMemberId: UUID?,
        today dayKey: String
    ) -> QuestionReminderPlan? {
        guard let question, let viewerMemberId, question.dayKey == dayKey else { return nil }
        return QuestionReminderPlan(
            dayKey: question.dayKey,
            partnerAnswered: question.hasAnswered(partnerMemberId),
            viewerAnswered: question.hasAnswered(viewerMemberId)
        )
    }
}
