import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class TodayQuestionModel {
    private(set) var question: DailyQuestionDTO?
    private(set) var text: String?

    @ObservationIgnored private let copy: QuestionCopy
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var reloadObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var reminder: QuestionReminderPlan?
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

    func start(_ environment: AppEnvironment, center: NotificationCenter = .default) async {
        self.environment = environment
        if reloadObserver == nil {
            reloadObserver = center.addObserver(
                forName: WidgetReloadRequest.notificationName,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor in await self?.refresh() }
            }
        }
        await open()
    }

    func stopObserving(center: NotificationCenter = .default) {
        guard let reloadObserver else { return }
        center.removeObserver(reloadObserver)
        self.reloadObserver = nil
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
        await scheduleReminder()
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
        await scheduleReminder()
    }

    func apply(_ updated: DailyQuestionDTO?) {
        question = updated
        text = updated.flatMap(copy.text)
        guard let updated, text != nil, shownDayKey != updated.dayKey else { return }
        shownDayKey = updated.dayKey
        environment?.analytics.record(.questionShown)
    }

    private func scheduleReminder() async {
        guard let environment, let space = environment.space else { return }
        let today = QuestionSelector.dayKey(for: now(), timeZone: space.anchorCalendarTimeZone)
        guard let plan = QuestionReminderPlanner.plan(
            question: question,
            viewerMemberId: environment.currentMember?.id,
            partnerMemberId: environment.partner?.id,
            today: today
        ), plan != reminder else { return }
        reminder = plan
        do {
            _ = try await environment.notifications.scheduleQuestionReminder(
                dayKey: plan.dayKey,
                on: now(),
                partnerName: environment.partnerName,
                partnerAnswered: plan.partnerAnswered,
                viewerAnswered: plan.viewerAnswered,
                prefs: environment.currentMember?.notificationPrefs ?? .allEnabled,
                now: now()
            )
        } catch {
            environment.report(error)
        }
    }
}
