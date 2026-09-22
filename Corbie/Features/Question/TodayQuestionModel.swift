import CorbieCore
import Foundation
import Observation

struct TodayQuestionLayout: Equatable {
    let questionId: UUID?
    let isCompact: Bool
}

@MainActor
@Observable
final class TodayQuestionModel {
    private(set) var question: DailyQuestionDTO?
    private(set) var text: String?

    @ObservationIgnored private let copy: QuestionCopy
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var storeChanges: StoreChangeSubscription?
    @ObservationIgnored private var shownDayKey: String?

    init(copy: QuestionCopy = QuestionCopy(), now: @escaping @Sendable () -> Date = { Date() }) {
        self.copy = copy
        self.now = now
    }

    var isVisible: Bool { question != nil && text != nil }

    var hasAnswered: Bool {
        guard let question, let memberId = environment?.currentMember?.id else { return false }
        return question.hasAnswered(memberId)
    }

    var status: QuestionStatus? {
        guard let question, let environment else { return nil }
        return environment.questionStatus(of: question, now: now())
    }

    var layout: TodayQuestionLayout {
        TodayQuestionLayout(questionId: question?.id, isCompact: status?.progress.isCompact ?? false)
    }

    func start(_ environment: AppEnvironment) async {
        self.environment = environment
        if storeChanges == nil {
            storeChanges = environment.repositories.changes.subscribe { [weak self] in
                await self?.refresh()
            }
        }
        await open()
    }

    func stopObserving() {
        storeChanges = nil
    }

    func open() async {
        guard let environment, let space = environment.space else {
            apply(nil)
            return
        }
        do {
            apply(
                try await environment.repositories.questions.todaysQuestion(
                    spaceId: space.id,
                    viewerMemberId: environment.currentMember?.id,
                    now: now()
                )
            )
        } catch {
            environment.report(error)
        }
        await environment.replanPartnerProgressReminders([.questionOfTheDay])
    }

    func refresh() async {
        guard let environment, let space = environment.space else {
            apply(nil)
            return
        }
        do {
            apply(
                try await environment.repositories.questions.storedQuestion(
                    spaceId: space.id,
                    viewerMemberId: environment.currentMember?.id,
                    now: now()
                )
            )
        } catch {
            environment.report(error)
        }
        await environment.replanPartnerProgressReminders([.questionOfTheDay])
    }

    func apply(_ updated: DailyQuestionDTO?) {
        question = updated
        text = updated.flatMap(copy.text)
        guard let updated, text != nil, shownDayKey != updated.dayKey else { return }
        shownDayKey = updated.dayKey
        environment?.analytics.record(.questionShown)
    }
}
