import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct CapsuleOpenReminderTriggerTests {
    private let foreign = "NSCloudKitMirroringDelegate.import"

    @Test func letterChangesFromTheOtherPhoneAskForAReplan() {
        for entity in [CapsuleItem.entityName, CapsuleOpen.entityName] {
            for type in RemoteChangeType.allCases {
                #expect(CapsuleOpenReminders.isTriggered(by: [record(entity, type: type)]))
            }
        }
    }

    @Test func ownWritesAndOtherEntitiesAskForNothing() {
        let own = record(CapsuleItem.entityName, author: TransactionAuthor.app.rawValue)
        let task = record(TaskItem.entityName)
        let unnamed = RemoteChangeRecord(objectURI: URL(fileURLWithPath: "/dev/null"), type: .insert, author: foreign)
        #expect(CapsuleOpenReminders.isTriggered(by: [own, task, unnamed]) == false)
        #expect(CapsuleOpenReminders.isTriggered(by: []) == false)
    }

    private func record(_ entityName: String, type: RemoteChangeType = .insert, author: String? = nil) -> RemoteChangeRecord {
        RemoteChangeRecord(
            objectURI: URL(fileURLWithPath: "/dev/null"),
            entityName: entityName,
            type: type,
            author: author ?? foreign
        )
    }
}

@Suite struct CapsuleOpenRescheduleTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "UTC")
    private let me = UUID()
    private let partner = UUID()

    @Test func everyUnopenedLetterGetsOneAlertAtNineOnItsDay() async throws {
        let center = FakeNotificationCenter()
        let received = letter(to: me, opens: "2026-10-14 09:00")
        let sent = letter(to: partner, opens: "2026-10-20 09:00")
        let requests = try await reschedule([received, sent], in: center)
        #expect(requests.count == 2)
        let receivedAlert = try #require(await center.request(id: NotificationIdentifier.capsuleOpens(capsuleId: received.id)))
        #expect(DomainClock.text(receivedAlert.fireDate, in: calendar) == "2026-10-14 09:00")
        #expect(receivedAlert.content.bodyKey == NotificationStrings.capsuleReceivedBody)
        #expect(receivedAlert.content.arguments == ["Sofia", received.title])
        let sentAlert = try #require(await center.request(id: NotificationIdentifier.capsuleOpens(capsuleId: sent.id)))
        #expect(sentAlert.content.bodyKey == NotificationStrings.capsuleSentBody)
    }

    @Test func replanningAgainLeavesOneAlertPerLetter() async throws {
        let center = FakeNotificationCenter()
        let letters = [letter(to: me, opens: "2026-10-14 09:00"), letter(to: me, opens: "2026-11-02 09:00")]
        try await reschedule(letters, in: center)
        try await reschedule(letters, in: center)
        #expect(await center.requests.count == 2)
        #expect(await center.removedIdentifiers.isEmpty)
    }

    @Test func aMovedDateMovesTheAlert() async throws {
        let center = FakeNotificationCenter()
        var moved = letter(to: me, opens: "2026-10-14 09:00")
        try await reschedule([moved], in: center)
        moved.opensAt = DomainClock.date("2026-12-24 09:00", in: calendar)
        try await reschedule([moved], in: center)
        #expect(await center.requests.count == 1)
        let alert = try #require(await center.request(id: NotificationIdentifier.capsuleOpens(capsuleId: moved.id)))
        #expect(DomainClock.text(alert.fireDate, in: calendar) == "2026-12-24 09:00")
    }

    @Test func aDeletedOpenedOrPastLetterLosesItsAlertAndOtherAlertsStay() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(client: center, calendar: calendar)
        let task = TaskDTO(id: UUID(), title: "Book the vet", dueAt: DomainClock.date("2026-10-15", in: calendar))
        _ = try await scheduler.scheduleTaskDueToday(for: task, prefs: .allEnabled, now: now)
        let kept = letter(to: me, opens: "2026-10-14 09:00")
        let deleted = letter(to: me, opens: "2026-10-15 09:00")
        var opened = letter(to: me, opens: "2026-10-16 09:00")
        var past = letter(to: me, opens: "2026-10-17 09:00")
        try await reschedule([kept, deleted, opened, past], in: center)
        opened.openedAt = now
        opened.openedByMemberIds = [me]
        past.opensAt = DomainClock.date("2026-10-12 09:00", in: calendar)
        try await reschedule([kept, opened, past], in: center)
        let ids = Set(await center.requests.map(\.id))
        #expect(ids == [
            NotificationIdentifier.taskDueToday(taskId: task.id),
            NotificationIdentifier.capsuleOpens(capsuleId: kept.id),
        ])
    }

    @Test func aLetterOnlyThePartnerOpenedKeepsMyAlert() async throws {
        let center = FakeNotificationCenter()
        var letter = letter(to: me, opens: "2026-10-14 09:00")
        try await reschedule([letter], in: center)
        letter.openedAt = now
        letter.openedByMemberIds = [partner]
        try await reschedule([letter], in: center)
        #expect(await center.request(id: NotificationIdentifier.capsuleOpens(capsuleId: letter.id)) != nil)
    }

    @Test func aLetterWrittenBeforePairingReadsAsReceivedForTheOtherMember() async throws {
        let center = FakeNotificationCenter()
        var unaddressed = letter(to: me, opens: "2026-10-14 09:00")
        unaddressed.recipientMemberId = nil
        try await reschedule([unaddressed], in: center)
        let alert = try #require(await center.request(id: NotificationIdentifier.capsuleOpens(capsuleId: unaddressed.id)))
        #expect(alert.content.titleKey == NotificationStrings.capsuleReceivedTitle)
    }

    @Test func turningLetterAlertsOffClearsThem() async throws {
        let center = FakeNotificationCenter()
        let letters = [letter(to: me, opens: "2026-10-14 09:00")]
        try await reschedule(letters, in: center)
        var prefs = NotificationPrefs.allEnabled
        prefs.capsuleUpdates = false
        try await reschedule(letters, in: center, prefs: prefs)
        #expect(await center.requests.isEmpty)
    }

    private var now: Date { DomainClock.date("2026-10-12 12:00", in: calendar) }

    private func letter(to recipient: UUID, opens: String) -> CapsuleDTO {
        CapsuleDTO(
            id: UUID(),
            authorMemberId: recipient == me ? partner : me,
            recipientMemberId: recipient,
            title: "Letter " + opens,
            opensAt: DomainClock.date(opens, in: calendar)
        )
    }

    @discardableResult
    private func reschedule(
        _ letters: [CapsuleDTO],
        in center: FakeNotificationCenter,
        prefs: NotificationPrefs = .allEnabled
    ) async throws -> [CorbieNotificationRequest] {
        try await NotificationScheduler(client: center, calendar: calendar).rescheduleCapsuleOpens(
            for: letters,
            viewerMemberId: me,
            partnerName: "Sofia",
            prefs: prefs,
            now: now
        )
    }
}

@Suite struct CapsuleOpenSyncTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "UTC")
    private let foreign = "NSCloudKitMirroringDelegate.import"

    @Test func aLetterThatArrivesBySyncIsScheduledWithoutOpeningTheApp() async throws {
        try await SyncWorld.run(calendar: calendar) { world in
            let letterId = try insertLetterAsThePartner(in: world, opensAt: "2026-10-14 09:00")
            try world.app.processHistory()
            await world.notifier.waitForPendingChanges()

            let alert = try #require(await world.center.request(id: NotificationIdentifier.capsuleOpens(capsuleId: letterId)))
            #expect(DomainClock.text(alert.fireDate, in: calendar) == "2026-10-14 09:00")
            #expect(alert.content.titleKey == NotificationStrings.capsuleReceivedTitle)
            #expect(alert.content.arguments == ["Sofia", "For our anniversary"])
            #expect(await world.center.requests.count == 1)
        }
    }

    @Test func aDateMovedOnThePartnersPhoneMovesTheAlert() async throws {
        try await SyncWorld.run(calendar: calendar) { world in
            let letterId = try insertLetterAsThePartner(in: world, opensAt: "2026-10-14 09:00")
            try world.app.processHistory()
            await world.notifier.waitForPendingChanges()

            try editLetterAsThePartner(in: world, id: letterId) { $0.opensAt = DomainClock.date("2026-11-30 09:00", in: calendar) }
            try world.app.processHistory()
            await world.notifier.waitForPendingChanges()

            #expect(await world.center.requests.count == 1)
            let alert = try #require(await world.center.request(id: NotificationIdentifier.capsuleOpens(capsuleId: letterId)))
            #expect(DomainClock.text(alert.fireDate, in: calendar) == "2026-11-30 09:00")
        }
    }

    @Test func aLetterDeletedOnThePartnersPhoneLosesItsAlert() async throws {
        try await SyncWorld.run(calendar: calendar) { world in
            let letterId = try insertLetterAsThePartner(in: world, opensAt: "2026-10-14 09:00")
            try world.app.processHistory()
            await world.notifier.waitForPendingChanges()

            #expect(await world.center.requests.count == 1)

            try editLetterAsThePartner(in: world, id: letterId) { $0.managedObjectContext?.delete($0) }
            try world.app.processHistory()
            await world.notifier.waitForPendingChanges()

            #expect(await world.center.requests.isEmpty)
            #expect(await world.center.removedIdentifiers == [NotificationIdentifier.capsuleOpens(capsuleId: letterId)])
        }
    }

    @Test func aLetterOpenedOnAnotherPhoneLosesItsAlert() async throws {
        try await SyncWorld.run(calendar: calendar) { world in
            let letterId = try insertLetterAsThePartner(in: world, opensAt: "2026-10-14 09:00")
            try world.app.processHistory()
            await world.notifier.waitForPendingChanges()

            #expect(await world.center.requests.count == 1)

            let meId = world.me.id
            try editLetterAsThePartner(in: world, id: letterId) { letter in
                guard let context = letter.managedObjectContext else { return }
                let open = CapsuleOpen(context: context)
                context.assign(open, toStoreOf: letter)
                open.capsule = letter
                open.memberId = meId
                open.openedAt = DomainClock.date("2026-10-12 11:00", in: calendar)
            }
            try world.app.processHistory()
            await world.notifier.waitForPendingChanges()

            #expect(await world.center.requests.isEmpty)
        }
    }

    private func insertLetterAsThePartner(in world: SyncWorld, opensAt: String) throws -> UUID {
        let context = world.writer.newBackgroundContext()
        context.transactionAuthor = foreign
        let spaceId = world.space.id
        let partnerId = world.partner.id
        let meId = world.me.id
        let opens = DomainClock.date(opensAt, in: calendar)
        return try context.performAndWait {
            let space: Space = try ManagedFetch.require(Space.entityName, id: spaceId, in: context)
            let letter = CapsuleItem(context: context)
            context.assign(letter, toStoreOf: space)
            letter.space = space
            letter.authorMemberId = partnerId
            letter.recipientMemberId = meId
            letter.title = "For our anniversary"
            letter.body = "Check the top drawer."
            letter.opensAt = opens
            try context.save()
            return letter.id ?? UUID()
        }
    }

    private func editLetterAsThePartner(in world: SyncWorld, id: UUID, _ edit: @escaping (CapsuleItem) -> Void) throws {
        let context = world.writer.newBackgroundContext()
        context.transactionAuthor = foreign
        try context.performAndWait {
            let letter: CapsuleItem = try ManagedFetch.require(CapsuleItem.entityName, id: id, in: context)
            edit(letter)
            try context.save()
        }
    }
}

private struct SyncWorld {
    let directory: URL
    let suiteName: String
    let app: CoreDataStack
    let writer: CoreDataStack
    let space: SpaceDTO
    let me: MemberDTO
    let partner: MemberDTO
    let center: FakeNotificationCenter
    let notifier: RemoteChangeNotifier

    private static func make(calendar: Calendar) async throws -> SyncWorld {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-letters-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suiteName = "corbie-letters-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
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
        let me = try await repositories.members.upsertCurrentMember(
            appleUserId: "apple-me",
            spaceId: space.id,
            draft: MemberDraft(displayName: "Ilya", colorKey: MemberColorSlot.creatorDefault.rawValue),
            theme: .sand
        ).member
        let partner = try await repositories.members.upsertCurrentMember(
            appleUserId: "apple-partner",
            spaceId: space.id,
            draft: MemberDraft(displayName: "Sofia", colorKey: MemberColorSlot.partnerDefault.rawValue),
            theme: .sand
        ).member
        try app.processHistory()

        let now = DomainClock.date("2026-10-12 12:00", in: calendar)
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(client: center, calendar: calendar)
        let notifier = RemoteChangeNotifier(
            stack: app,
            scheduler: scheduler,
            reminders: PartnerProgressReminders(
                chores: repositories.chores,
                questions: repositories.questions,
                scheduler: scheduler,
                defaults: defaults,
                now: { now }
            ),
            capsuleOpens: CapsuleOpenReminders(capsules: repositories.capsules, scheduler: scheduler, now: { now }),
            defaults: defaults
        )
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
        return SyncWorld(
            directory: directory,
            suiteName: suiteName,
            app: app,
            writer: writer,
            space: space,
            me: me,
            partner: partner,
            center: center,
            notifier: notifier
        )
    }

    static func run(calendar: Calendar, _ body: (SyncWorld) async throws -> Void) async throws {
        let world = try await make(calendar: calendar)
        do {
            try await body(world)
        } catch {
            await world.tearDown()
            throw error
        }
        await world.tearDown()
    }

    private func tearDown() async {
        await notifier.stop()
        await notifier.waitForPendingChanges()
        for stack in [writer, app] {
            let coordinator = stack.container.persistentStoreCoordinator
            for store in coordinator.persistentStores {
                try? coordinator.remove(store)
            }
        }
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }
}
