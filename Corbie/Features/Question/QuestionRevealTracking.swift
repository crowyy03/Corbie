import CorbieCore
import Foundation

extension AppEnvironment {
    func questionStatus(of question: DailyQuestionDTO, now: Date = Date()) -> QuestionStatus? {
        guard let space else { return nil }
        return QuestionStatus(
            question: question,
            todayKey: QuestionStatus.todayKey(now: now, space: space),
            viewer: currentMember,
            partnerId: partner?.id
        )
    }

    func markRevealRead(_ question: DailyQuestionDTO, now: Date = Date()) async {
        guard let member = currentMember, questionStatus(of: question, now: now)?.progress == .revealUnread else {
            return
        }
        do {
            let reader = try await repositories.questions.markRevealRead(memberId: member.id, dayKey: question.dayKey)
            apply(member: reader)
            await usBadge.refresh(space: space, viewer: reader, partner: partner)
        } catch {
            report(error)
        }
    }
}
