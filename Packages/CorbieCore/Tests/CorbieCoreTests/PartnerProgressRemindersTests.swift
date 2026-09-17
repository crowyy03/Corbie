import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct PartnerProgressReminderTriggerTests {
    private let foreign = "NSCloudKitMirroringDelegate.import"

    @Test func choreChangesFromTheOtherPhoneAskForTheChoreNotice() {
        for entity in [ChoreSet.entityName, ChoreItem.entityName, ChoreRating.entityName] {
            #expect(PartnerProgressReminder.triggered(by: [record(entity)]) == [.choreSplitReady])
        }
    }

    @Test func questionChangesFromTheOtherPhoneAskForTheQuestionReminder() {
        for entity in [DailyQuestion.entityName, QuestionAnswer.entityName] {
            #expect(PartnerProgressReminder.triggered(by: [record(entity)]) == [.questionOfTheDay])
        }
    }

    @Test func aDeletedRatingStillAsksBecauseTheSplitMayHaveChanged() {
        #expect(PartnerProgressReminder.triggered(by: [record(ChoreRating.entityName, type: .delete)]) == [.choreSplitReady])
    }

    @Test func ownWritesAndOtherEntitiesAskForNothing() {
        let own = record(ChoreRating.entityName, author: TransactionAuthor.app.rawValue)
        let task = record(TaskItem.entityName)
        let unnamed = RemoteChangeRecord(objectURI: URL(fileURLWithPath: "/dev/null"), type: .insert, author: foreign)
        #expect(PartnerProgressReminder.triggered(by: [own, task, unnamed]).isEmpty)
        #expect(PartnerProgressReminder.triggered(by: []).isEmpty)
    }

    @Test func aMixedBatchAsksForBoth() {
        let batch = [record(TaskItem.entityName), record(QuestionAnswer.entityName), record(ChoreRating.entityName)]
        #expect(PartnerProgressReminder.triggered(by: batch) == [.choreSplitReady, .questionOfTheDay])
    }

    private func record(
        _ entityName: String,
        type: RemoteChangeType = .insert,
        author: String? = nil
    ) -> RemoteChangeRecord {
        RemoteChangeRecord(
            objectURI: URL(fileURLWithPath: "/dev/null"),
            entityName: entityName,
            type: type,
            author: author ?? foreign
        )
    }
}

@Suite struct ChoreReminderPlannerTests {
    private let viewerId = UUID()
    private let partnerId = UUID()

    @Test func thePartnerFinishingFirstEarnsANotice() throws {
        let plan = try #require(
            ChoreReminderPlanner.plan(
                sets: [set(rated: [partnerId])],
                viewerMemberId: viewerId,
                partnerMemberId: partnerId,
                partnerName: "Sofia",
                alreadyToldAbout: nil
            )
        )
        #expect(plan.partnerName == "Sofia")
    }

    @Test func nobodyIsToldTwiceAboutTheSameSplit() {
        let waiting = set(rated: [partnerId])
        let plan = ChoreReminderPlanner.plan(
            sets: [waiting],
            viewerMemberId: viewerId,
            partnerMemberId: partnerId,
            partnerName: "Sofia",
            alreadyToldAbout: waiting.id.uuidString
        )
        #expect(plan == nil)
    }

    @Test func thereIsNothingToSayWhileThePartnerIsStillRating() {
        #expect(plan(for: [set(rated: [])]) == nil)
        #expect(plan(for: [set(rated: [viewerId])]) == nil)
        #expect(plan(for: [set(rated: [viewerId, partnerId])]) == nil)
        #expect(plan(for: [set(status: .building, rated: [partnerId])]) == nil)
        #expect(plan(for: []) == nil)
    }

    private func plan(for sets: [ChoreSetDTO]) -> ChoreReminderPlan? {
        ChoreReminderPlanner.plan(
            sets: sets,
            viewerMemberId: viewerId,
            partnerMemberId: partnerId,
            partnerName: "Sofia",
            alreadyToldAbout: nil
        )
    }

    private func set(status: ChoreSetStatus = .rating, rated: [UUID]) -> ChoreSetDTO {
        ChoreSetDTO(
            id: UUID(),
            status: status,
            items: (0 ..< ChoreSetDTO.minimumIncludedItems).map {
                ChoreItemDTO(id: UUID(), title: "chore \($0)", sortIndex: $0)
            },
            ratedMemberIds: rated
        )
    }
}

@Suite struct QuestionReminderPlannerTests {
    private let viewerId = UUID()
    private let partnerId = UUID()

    @Test func theReminderIsPlannedForTheDayTheQuestionBelongsTo() throws {
        let plan = try #require(
            QuestionReminderPlanner.plan(
                question: question(dayKey: "2026-09-07"),
                viewerMemberId: viewerId,
                partnerMemberId: partnerId,
                today: "2026-09-07"
            )
        )
        #expect(plan.dayKey == "2026-09-07")
        #expect(plan.partnerAnswered == false)
        #expect(plan.viewerAnswered == false)
    }

    @Test func aQuestionFromAnotherDayIsNotWorthAReminder() {
        let plan = QuestionReminderPlanner.plan(
            question: question(dayKey: "2026-09-06"),
            viewerMemberId: viewerId,
            partnerMemberId: partnerId,
            today: "2026-09-07"
        )
        #expect(plan == nil)
    }

    @Test func withoutAQuestionOrAViewerThereIsNothingToPlan() {
        let noQuestion = QuestionReminderPlanner.plan(
            question: nil,
            viewerMemberId: viewerId,
            partnerMemberId: partnerId,
            today: "2026-09-07"
        )
        let noViewer = QuestionReminderPlanner.plan(
            question: question(dayKey: "2026-09-07"),
            viewerMemberId: nil,
            partnerMemberId: partnerId,
            today: "2026-09-07"
        )
        #expect(noQuestion == nil)
        #expect(noViewer == nil)
    }

    @Test func thePlanReportsWhoHasAlreadyWritten() throws {
        var today = question(dayKey: "2026-09-07")
        today.answers = [QuestionAnswerDTO(id: UUID(), memberId: partnerId, text: "The bread we burned")]
        let waiting = try #require(
            QuestionReminderPlanner.plan(
                question: today,
                viewerMemberId: viewerId,
                partnerMemberId: partnerId,
                today: "2026-09-07"
            )
        )
        #expect(waiting.partnerAnswered)
        #expect(waiting.viewerAnswered == false)

        today.answers.append(QuestionAnswerDTO(id: UUID(), memberId: viewerId, text: "A dog on the tram"))
        let done = try #require(
            QuestionReminderPlanner.plan(
                question: today,
                viewerMemberId: viewerId,
                partnerMemberId: partnerId,
                today: "2026-09-07"
            )
        )
        #expect(done.viewerAnswered)
    }

    @Test func aPartnerNobodyHasJoinedYetNeverCountsAsAnswered() throws {
        var today = question(dayKey: "2026-09-07")
        today.answers = [QuestionAnswerDTO(id: UUID(), memberId: viewerId, text: "A dog on the tram")]
        let plan = try #require(
            QuestionReminderPlanner.plan(
                question: today,
                viewerMemberId: viewerId,
                partnerMemberId: nil,
                today: "2026-09-07"
            )
        )
        #expect(plan.partnerAnswered == false)
        #expect(plan.viewerAnswered)
    }

    private func question(dayKey: String) -> DailyQuestionDTO {
        DailyQuestionDTO(id: UUID(), questionId: "q0001", dayKey: dayKey)
    }
}

@Suite struct PartnerProgressRemindersTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "UTC")

    @Test func theChoreNoticeIsScheduledOnceWhenThePartnerFinishesFirst() async throws {
        let fixture = try await Fixture.make(calendar: calendar)
        let set = try await fixture.startRating(ratedBy: fixture.world.partner.id)
        let audience = fixture.audience()

        await fixture.reminders.replan([.choreSplitReady], for: audience)
        let notice = try #require(await fixture.center.request(id: NotificationIdentifier.choreSplitReady(setId: set.id)))
        #expect(notice.isImmediate)
        #expect(notice.content.arguments == ["Sofia"])
        #expect(fixture.defaults.string(forKey: ChoreReminderPlanner.toldKey) == set.id.uuidString)

        await fixture.reminders.replan([.choreSplitReady], for: audience)
        await fixture.reminders.replan([.choreSplitReady, .questionOfTheDay], for: audience)
        #expect(await fixture.center.removedIdentifiers.count == 1)
        #expect(await fixture.center.requests.count == 1)
    }

    @Test func theChoreNoticeKeepsItsPreference() async throws {
        let fixture = try await Fixture.make(calendar: calendar)
        _ = try await fixture.startRating(ratedBy: fixture.world.partner.id)
        var prefs = NotificationPrefs.allEnabled
        prefs.choreSplitReady = false

        await fixture.reminders.replan([.choreSplitReady], for: fixture.audience(prefs: prefs))
        #expect(await fixture.center.requests.isEmpty)
    }

    @Test func theOneWhoFinishedFirstIsNotTold() async throws {
        let fixture = try await Fixture.make(calendar: calendar)
        _ = try await fixture.startRating(ratedBy: fixture.world.me.id)

        await fixture.reminders.replan([.choreSplitReady], for: fixture.audience())
        #expect(await fixture.center.requests.isEmpty)
        #expect(fixture.defaults.string(forKey: ChoreReminderPlanner.toldKey) == nil)
    }

    @Test func thePartnersAnswerMovesTheQuestionReminderToTheMorning() async throws {
        let fixture = try await Fixture.make(calendar: calendar)
        let id = NotificationIdentifier.questionOfTheDay(dayKey: "2026-09-07")
        let question = try #require(
            try await fixture.questions.todaysQuestion(spaceId: fixture.world.space.id, now: fixture.now)
        )
        let audience = fixture.audience()

        await fixture.reminders.replan([.questionOfTheDay], for: audience)
        let evening = try #require(await fixture.center.request(id: id))
        #expect(DomainClock.text(evening.fireDate, in: calendar) == "2026-09-07 20:00")

        _ = try await fixture.questions.answer(
            dailyQuestionId: question.id,
            memberId: fixture.world.partner.id,
            text: "The bread we burned",
            at: fixture.now
        )
        await fixture.reminders.replan([.questionOfTheDay], for: audience)
        let morning = try #require(await fixture.center.request(id: id))
        #expect(DomainClock.text(morning.fireDate, in: calendar) == "2026-09-07 10:00")
        #expect(morning.content.bodyKey == NotificationStrings.questionBodyPartner)
        #expect(morning.content.arguments == ["Sofia"])

        let removedBefore = await fixture.center.removedIdentifiers.count
        await fixture.reminders.replan([.questionOfTheDay], for: audience)
        #expect(await fixture.center.removedIdentifiers.count == removedBefore)
        #expect(await fixture.center.requests.count == 1)
    }

    @Test func theQuestionReminderKeepsItsPreference() async throws {
        let fixture = try await Fixture.make(calendar: calendar)
        _ = try await fixture.questions.todaysQuestion(spaceId: fixture.world.space.id, now: fixture.now)
        var prefs = NotificationPrefs.allEnabled
        prefs.questionOfTheDay = false

        await fixture.reminders.replan([.questionOfTheDay], for: fixture.audience(prefs: prefs))
        #expect(await fixture.center.requests.isEmpty)

        await fixture.reminders.replan([.questionOfTheDay], for: fixture.audience())
        #expect(await fixture.center.requests.count == 1)
    }

    @Test func noQuestionForTodayMeansNoReminder() async throws {
        let fixture = try await Fixture.make(calendar: calendar)
        await fixture.reminders.replan([.questionOfTheDay], for: fixture.audience())
        #expect(await fixture.center.requests.isEmpty)
    }
}

@Suite struct RemoteChangeNotifierWaitTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "UTC")
    private let foreign = "NSCloudKitMirroringDelegate.import"

    @Test func partnerChangesAreClassifiedBeforeTheWaitEnds() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "corbie-remote-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let app = CoreDataStack(
            directory: directory,
            author: .app,
            mirroring: .disabled,
            historyDefaults: defaults,
            requiresAppGroup: false
        )
        #expect(app.loadFailure == nil)
        let repositories = Repositories(stack: app)
        let space = try await repositories.spaces.create(displayCurrency: "USD")
        let me = try await member("apple-me", name: "Ilya", slot: .creatorDefault, space: space.id, in: repositories)
        let partner = try await member("apple-partner", name: "Sofia", slot: .partnerDefault, space: space.id, in: repositories)
        let now = DomainClock.date("2026-09-07 07:30", in: calendar)
        let chores = CoreDataChoreRepository(stack: app, catalog: .bundled, locale: Locale(identifier: "en_US"))
        let set = try await chores.startSet(spaceId: space.id, catalogIds: [], memberId: me.id, at: now)
        _ = try await chores.startRating(setId: set.id)
        try app.processHistory()

        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(client: center, calendar: calendar)
        let reminders = PartnerProgressReminders(
            chores: chores,
            questions: CoreDataQuestionRepository(stack: app),
            scheduler: scheduler,
            defaults: defaults,
            now: { now }
        )
        let notifier = RemoteChangeNotifier(stack: app, scheduler: scheduler, reminders: reminders, defaults: defaults)
        await notifier.update(
            audience: RemoteChangeNotifier.Audience(
                spaceId: space.id,
                memberId: me.id,
                partnerId: partner.id,
                partnerName: "Sofia",
                timeZone: calendar.timeZone
            )
        )
        await notifier.start()

        let writer = CoreDataStack(storesIn: directory, author: .tests)
        let taskId = try writeAsThePartner(in: writer, setId: set.id, spaceId: space.id, partnerId: partner.id, meId: me.id)
        try app.processHistory()
        await notifier.waitForPendingChanges()

        #expect(await center.request(id: NotificationIdentifier.choreSplitReady(setId: set.id)) != nil)
        #expect(await center.request(id: RemoteChangeKind.taskAssigned.prefix + taskId.uuidString) != nil)

        try rerateAsThePartner(in: writer, setId: set.id, partnerId: partner.id)
        try app.processHistory()
        await notifier.waitForPendingChanges()
        #expect(await center.requests.count == 2)
        #expect(await center.removedIdentifiers == [NotificationIdentifier.choreSplitReady(setId: set.id)])
    }

    private func member(
        _ appleUserId: String,
        name: String,
        slot: MemberColorSlot,
        space: UUID,
        in repositories: Repositories
    ) async throws -> MemberDTO {
        try await repositories.members.upsertCurrentMember(
            appleUserId: appleUserId,
            spaceId: space,
            draft: MemberDraft(displayName: name, colorKey: slot.rawValue),
            theme: .sand
        ).member
    }

    private func writeAsThePartner(
        in writer: CoreDataStack,
        setId: UUID,
        spaceId: UUID,
        partnerId: UUID,
        meId: UUID
    ) throws -> UUID {
        let context = writer.newBackgroundContext()
        context.transactionAuthor = foreign
        return try context.performAndWait {
            let set: ChoreSet = try ManagedFetch.require(ChoreSet.entityName, id: setId, in: context)
            for item in set.items where item.isIncluded {
                let rating = ChoreRating(context: context)
                context.assign(rating, toStoreOf: item)
                rating.choreItem = item
                rating.memberId = partnerId
                rating.verdict = .fine
            }
            let space: Space = try ManagedFetch.require(Space.entityName, id: spaceId, in: context)
            let task = TaskItem(context: context)
            context.assign(task, toStoreOf: space)
            task.space = space
            task.title = "Call the bank"
            task.assigneeMemberId = meId
            task.createdByMemberId = partnerId
            try context.save()
            return task.id ?? UUID()
        }
    }

    private func rerateAsThePartner(in writer: CoreDataStack, setId: UUID, partnerId: UUID) throws {
        let context = writer.newBackgroundContext()
        context.transactionAuthor = foreign
        try context.performAndWait {
            let set: ChoreSet = try ManagedFetch.require(ChoreSet.entityName, id: setId, in: context)
            for rating in set.items.flatMap(\.ratings) where rating.memberId == partnerId {
                rating.verdict = .like
            }
            try context.save()
        }
    }

    private func makeDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-remote-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private struct Fixture {
    let world: TestWorld
    let questions: CoreDataQuestionRepository
    let chores: CoreDataChoreRepository
    let center: FakeNotificationCenter
    let reminders: PartnerProgressReminders
    let defaults: UserDefaults
    let now: Date
    let calendar: Calendar

    static func make(calendar: Calendar) async throws -> Fixture {
        let world = try await TestWorld.make()
        var space = world.space
        space.anchorTimeZone = "UTC"
        space.togetherSince = DomainClock.date("2020-01-01", in: calendar)
        _ = try await world.repositories.spaces.update(space)
        let stack = world.controller.stack
        let questions = CoreDataQuestionRepository(
            stack: stack,
            bank: QuestionBank(entries: [
                QuestionBankEntry(
                    id: "q0001",
                    theme: .everyday,
                    stage: .any,
                    tone: .light,
                    text: ["en": "What made you laugh today"]
                ),
            ]),
            locale: Locale(identifier: "en_US")
        )
        let chores = CoreDataChoreRepository(stack: stack, catalog: .bundled, locale: Locale(identifier: "en_US"))
        let center = FakeNotificationCenter()
        let suiteName = "corbie-reminders-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let now = DomainClock.date("2026-09-07 07:30", in: calendar)
        let reminders = PartnerProgressReminders(
            chores: chores,
            questions: questions,
            scheduler: NotificationScheduler(client: center, calendar: calendar),
            defaults: defaults,
            now: { now }
        )
        return Fixture(
            world: world,
            questions: questions,
            chores: chores,
            center: center,
            reminders: reminders,
            defaults: defaults,
            now: now,
            calendar: calendar
        )
    }

    func audience(prefs: NotificationPrefs = .allEnabled) -> RemoteChangeNotifier.Audience {
        RemoteChangeNotifier.Audience(
            spaceId: world.space.id,
            memberId: world.me.id,
            partnerId: world.partner.id,
            partnerName: world.partner.displayName ?? "",
            prefs: prefs,
            timeZone: calendar.timeZone
        )
    }

    func startRating(ratedBy memberId: UUID) async throws -> ChoreSetDTO {
        let set = try await chores.startSet(spaceId: world.space.id, catalogIds: [], memberId: world.me.id, at: now)
        var latest = set
        for item in set.includedItems {
            latest = try await chores.rate(itemId: item.id, memberId: memberId, verdict: .fine, at: now)
        }
        return latest
    }
}
