import Foundation
import Testing
@testable import CorbieCore

@Suite struct RemoteChangeClassifierTests {
    private let me = UUID()
    private let partner = UUID()

    private var viewer: RemoteChangeViewer {
        RemoteChangeViewer(memberId: me, partnerId: partner, partnerName: "Sofia")
    }

    @Test func aTaskAssignedToMeByThePartnerBecomesAnAssignedAlert() {
        let task = TaskDTO(id: UUID(), title: "Book the table", assigneeMemberId: me, createdByMemberId: partner)
        let alert = RemoteChangeClassifier.alert(
            for: RemoteChange(type: .insert, subject: .task(task)),
            viewer: viewer
        )
        #expect(alert?.kind == .taskAssigned)
        #expect(alert?.content.categoryIdentifier == NotificationCategories.task)
        #expect(alert?.content.userInfo[NotificationPayload.routeKey] == CorbieRoute.task(task.id).urlString)
    }

    @Test func aTaskIAssignedToMyselfDoesNotAlertMe() {
        let task = TaskDTO(id: UUID(), title: "Pay rent", assigneeMemberId: me, createdByMemberId: me)
        #expect(RemoteChangeClassifier.alert(for: RemoteChange(type: .insert, subject: .task(task)), viewer: viewer) == nil)
    }

    @Test func onlyAnAssigneeChangeCountsAsAHandover() {
        let taken = TaskDTO(id: UUID(), title: "Groceries", assigneeMemberId: partner)
        let renamed = RemoteChange(type: .update, properties: ["title"], subject: .task(taken))
        #expect(RemoteChangeClassifier.alert(for: renamed, viewer: viewer) == nil)
        let handover = RemoteChange(
            type: .update,
            properties: [RemoteChangeProperty.taskAssignee],
            subject: .task(taken)
        )
        #expect(RemoteChangeClassifier.alert(for: handover, viewer: viewer)?.kind == .taskHandover)
    }

    @Test func aTaskHandedBackToFreeUsesTheHandedBackCopy() {
        let free = TaskDTO(id: UUID(), title: "Call the landlord")
        let alert = RemoteChangeClassifier.alert(
            for: RemoteChange(type: .update, properties: [RemoteChangeProperty.taskAssignee], subject: .task(free)),
            viewer: viewer
        )
        #expect(alert?.content.titleKey == NotificationStrings.taskHandedBackTitle)
    }

    @Test func aDoneTaskNeverAlerts() {
        var task = TaskDTO(id: UUID(), title: "Done already", assigneeMemberId: me, createdByMemberId: partner)
        task.isDone = true
        #expect(RemoteChangeClassifier.alert(for: RemoteChange(type: .insert, subject: .task(task)), viewer: viewer) == nil)
    }

    @Test func onlyAWishAddedByThePartnerAlerts() {
        let mine = WishDTO(id: UUID(), addedByMemberId: me, title: "Headphones")
        #expect(RemoteChangeClassifier.alert(for: RemoteChange(type: .insert, subject: .wish(mine)), viewer: viewer) == nil)
        let theirs = WishDTO(id: UUID(), addedByMemberId: partner, title: "Headphones")
        let alert = RemoteChangeClassifier.alert(for: RemoteChange(type: .insert, subject: .wish(theirs)), viewer: viewer)
        #expect(alert?.kind == .partnerWish)
    }

    @Test func aPlanAlertsOnlyWhenTheGoalIsReached() {
        var plan = PlanDTO(id: UUID(), title: "Lisbon", targetAmount: 5000, savedAmount: 2400)
        let short = RemoteChange(type: .update, properties: [RemoteChangeProperty.planSaved], subject: .plan(plan))
        #expect(RemoteChangeClassifier.alert(for: short, viewer: viewer) == nil)
        plan.savedAmount = 5000
        let reached = RemoteChange(type: .update, properties: [RemoteChangeProperty.planSaved], subject: .plan(plan))
        let alert = RemoteChangeClassifier.alert(for: reached, viewer: viewer)
        #expect(alert?.kind == .planUpdate)
        #expect(alert?.content.titleKey == NotificationStrings.planGoalTitle)
    }

    @Test func anExpenseOverTheTargetUsesTheOverBudgetCopy() {
        var plan = PlanDTO(id: UUID(), title: "Kitchen", targetAmount: 1000, savedAmount: 1000)
        plan.spentAmount = 1340
        let expense = PlanExpenseDTO(id: UUID(), planId: plan.id, amount: 340, addedByMemberId: partner)
        let alert = RemoteChangeClassifier.alert(
            for: RemoteChange(type: .insert, subject: .expense(expense, plan: plan)),
            viewer: viewer
        )
        #expect(alert?.content.titleKey == NotificationStrings.planOverTitle)
    }

    @Test func myOwnExpenseDoesNotAlertMe() {
        let plan = PlanDTO(id: UUID(), title: "Kitchen", targetAmount: 1000)
        let expense = PlanExpenseDTO(id: UUID(), planId: plan.id, amount: 40, addedByMemberId: me)
        #expect(
            RemoteChangeClassifier.alert(
                for: RemoteChange(type: .insert, subject: .expense(expense, plan: plan)),
                viewer: viewer
            ) == nil
        )
    }

    @Test func aCapsuleOpenedByThePartnerAlertsAndMyOwnOpenDoesNot() {
        let capsule = CapsuleDTO(id: UUID(), authorMemberId: me, recipientMemberId: partner, title: "First year")
        let theirs = RemoteChange(type: .insert, subject: .capsuleOpen(capsule: capsule, memberId: partner))
        #expect(RemoteChangeClassifier.alert(for: theirs, viewer: viewer)?.kind == .capsuleOpened)
        let mine = RemoteChange(type: .insert, subject: .capsuleOpen(capsule: capsule, memberId: me))
        #expect(RemoteChangeClassifier.alert(for: mine, viewer: viewer) == nil)
    }

    @Test func aVoteAlertsOnCreationByThePartnerAndOnReveal() {
        var vote = VoteDTO(id: UUID(), question: "Where to eat", options: ["Home", "Out"], createdByMemberId: partner)
        let created = RemoteChangeClassifier.alert(for: RemoteChange(type: .insert, subject: .vote(vote)), viewer: viewer)
        #expect(created?.kind == .voteUpdate)
        #expect(created?.content.categoryIdentifier == NotificationCategories.vote)
        vote.revealedAt = Date()
        let revealed = RemoteChangeClassifier.alert(
            for: RemoteChange(type: .update, properties: [RemoteChangeProperty.voteRevealed], subject: .vote(vote)),
            viewer: viewer
        )
        #expect(revealed?.content.titleKey == NotificationStrings.voteRevealedTitle)
        #expect(created?.id != revealed?.id)
    }

    @Test func twoChangesToTheSameTaskProduceOneAlert() {
        let task = TaskDTO(id: UUID(), title: "Pack", assigneeMemberId: me, createdByMemberId: partner)
        let alerts = RemoteChangeClassifier.alerts(
            for: [
                RemoteChange(type: .insert, subject: .task(task)),
                RemoteChange(type: .update, properties: [RemoteChangeProperty.taskAssignee], subject: .task(task))
            ],
            viewer: viewer
        )
        #expect(alerts.count == 1)
    }

    @Test func everyRemoteKindIsGatedByItsOwnPreference() {
        for kind in RemoteChangeKind.allCases {
            #expect(kind.isEnabled(in: .allEnabled))
            var prefs = NotificationPrefs.allEnabled
            switch kind {
            case .taskAssigned: prefs.taskAssigned = false
            case .taskHandover: prefs.taskTakenOrHandedBack = false
            case .partnerWish: prefs.partnerAddedWish = false
            case .planUpdate: prefs.planUpdates = false
            case .capsuleOpened: prefs.capsuleUpdates = false
            case .voteUpdate: prefs.voteUpdates = false
            }
            #expect(kind.isEnabled(in: prefs) == false)
        }
    }

    @Test func deliveringRespectsThePreferenceAndFiresImmediately() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(client: center)
        let task = TaskDTO(id: UUID(), title: "Book the table", assigneeMemberId: me, createdByMemberId: partner)
        let alert = try #require(
            RemoteChangeClassifier.alert(for: RemoteChange(type: .insert, subject: .task(task)), viewer: viewer)
        )
        var off = NotificationPrefs.allEnabled
        off.taskAssigned = false
        #expect(try await scheduler.deliver(alert, prefs: off) == nil)
        #expect(await center.requests.isEmpty)
        let delivered = try await scheduler.deliver(alert, prefs: .allEnabled)
        #expect(delivered?.isImmediate == true)
        #expect(await center.requests.count == 1)
    }

    @Test func aDeliveryTheNotificationCentreRefusesIsReportedAsAFailure() async throws {
        let center = FakeNotificationCenter(addFailure: CorbieError.persistence("notification centre is busy"))
        let scheduler = NotificationScheduler(client: center)
        let task = TaskDTO(id: UUID(), title: "Book the table", assigneeMemberId: me, createdByMemberId: partner)
        let alert = try #require(
            RemoteChangeClassifier.alert(for: RemoteChange(type: .insert, subject: .task(task)), viewer: viewer)
        )
        await #expect(throws: CorbieError.persistence("notification centre is busy")) {
            _ = try await scheduler.deliver(alert, prefs: .allEnabled)
        }
        #expect(await center.requests.isEmpty)
    }

    @Test func aChangeWrittenByThisDeviceIsNotTreatedAsRemote() {
        let uri = URL(fileURLWithPath: "/dev/null")
        let local = RemoteChangeRecord(
            entityName: TaskItem.entityName,
            objectURI: uri,
            type: .insert,
            author: TransactionAuthor.widgets.rawValue
        )
        #expect(local.isFromAnotherDevice == false)
        let remote = RemoteChangeRecord(
            entityName: TaskItem.entityName,
            objectURI: uri,
            type: .insert,
            author: "NSCloudKitMirroringDelegate.import"
        )
        #expect(remote.isFromAnotherDevice)
    }
}
