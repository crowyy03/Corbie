import Foundation
import os

public enum PartnerProgressReminder: Sendable, Hashable, CaseIterable {
    case choreSplitReady
    case questionOfTheDay

    static let choreEntities: Set<String> = [ChoreSet.entityName, ChoreItem.entityName, ChoreRating.entityName]
    static let questionEntities: Set<String> = [DailyQuestion.entityName, QuestionAnswer.entityName]

    public static func triggered(by records: [RemoteChangeRecord]) -> Set<PartnerProgressReminder> {
        var reminders: Set<PartnerProgressReminder> = []
        for record in records where record.isFromAnotherDevice {
            guard let entityName = record.entityName else { continue }
            if choreEntities.contains(entityName) {
                reminders.insert(.choreSplitReady)
            }
            if questionEntities.contains(entityName) {
                reminders.insert(.questionOfTheDay)
            }
        }
        return reminders
    }
}

public actor PartnerProgressReminders {
    private struct QuestionReminderRequest: Equatable {
        let spaceId: UUID
        let memberId: UUID
        let plan: QuestionReminderPlan
        let partnerName: String
        let isEnabled: Bool
    }

    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "reminders")

    private let chores: any ChoreRepository
    private let questions: any QuestionRepository
    private let scheduler: NotificationScheduler
    private let defaults: UserDefaults
    private let now: @Sendable () -> Date

    private var lastQuestionRequest: QuestionReminderRequest?
    private var queue: Task<Void, Never>?

    public init(
        chores: any ChoreRepository,
        questions: any QuestionRepository,
        scheduler: NotificationScheduler,
        defaults: UserDefaults = .corbieShared,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.chores = chores
        self.questions = questions
        self.scheduler = scheduler
        self.defaults = defaults
        self.now = now
    }

    public func replan(_ reminders: Set<PartnerProgressReminder>, for audience: RemoteChangeNotifier.Audience) async {
        guard reminders.isEmpty == false else { return }
        let previous = queue
        let work = Task {
            await previous?.value
            await self.plan(reminders, for: audience)
        }
        queue = work
        await work.value
    }

    private func plan(_ reminders: Set<PartnerProgressReminder>, for audience: RemoteChangeNotifier.Audience) async {
        if reminders.contains(.choreSplitReady) {
            await planChoreSplitNotice(for: audience)
        }
        if reminders.contains(.questionOfTheDay) {
            await planQuestionReminder(for: audience)
        }
    }

    private func planChoreSplitNotice(for audience: RemoteChangeNotifier.Audience) async {
        let sets: [ChoreSetDTO]
        do {
            sets = try await chores.history(spaceId: audience.spaceId, viewerMemberId: audience.memberId)
        } catch {
            PartnerProgressReminders.log.error("chore sets unreadable: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard let plan = ChoreReminderPlanner.plan(
            sets: sets,
            viewerMemberId: audience.memberId,
            partnerMemberId: audience.partnerId,
            partnerName: audience.partnerName,
            alreadyToldAbout: defaults.string(forKey: ChoreReminderPlanner.toldKey)
        ) else { return }
        defaults.set(plan.setId.uuidString, forKey: ChoreReminderPlanner.toldKey)
        do {
            try await scheduler.scheduleChoreSplitReady(
                setId: plan.setId,
                partnerName: plan.partnerName,
                prefs: audience.prefs,
                now: now()
            )
        } catch {
            PartnerProgressReminders.log.error("chore notice not scheduled: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func planQuestionReminder(for audience: RemoteChangeNotifier.Audience) async {
        let current = now()
        let question: DailyQuestionDTO?
        do {
            question = try await questions.storedQuestion(
                spaceId: audience.spaceId,
                viewerMemberId: audience.memberId,
                now: current
            )
        } catch {
            PartnerProgressReminders.log.error("question unreadable: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard let plan = QuestionReminderPlanner.plan(
            question: question,
            viewerMemberId: audience.memberId,
            partnerMemberId: audience.partnerId,
            today: QuestionSelector.dayKey(for: current, timeZone: audience.timeZone)
        ) else { return }
        let request = QuestionReminderRequest(
            spaceId: audience.spaceId,
            memberId: audience.memberId,
            plan: plan,
            partnerName: audience.partnerName,
            isEnabled: NotificationKind.questionOfTheDay.isEnabled(in: audience.prefs)
        )
        guard request != lastQuestionRequest else { return }
        lastQuestionRequest = request
        do {
            _ = try await scheduler.scheduleQuestionReminder(
                dayKey: plan.dayKey,
                on: current,
                partnerName: audience.partnerName,
                partnerAnswered: plan.partnerAnswered,
                viewerAnswered: plan.viewerAnswered,
                prefs: audience.prefs,
                now: current
            )
        } catch {
            lastQuestionRequest = nil
            PartnerProgressReminders.log.error("question reminder not scheduled: \(error.localizedDescription, privacy: .public)")
        }
    }
}
