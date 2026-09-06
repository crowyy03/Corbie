import CorbieCore
import XCTest
@testable import Corbie

@MainActor
final class TasksViewModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_757_000_000)

    func testCountsAndGroupsSplitAssignedFromFree() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)

        XCTAssertEqual(model.counts.all, 4)
        XCTAssertEqual(model.counts.mine, 1)
        XCTAssertEqual(model.counts.partner, 1)
        XCTAssertEqual(model.counts.free, 2)

        XCTAssertEqual(model.groups.map(\.kind), [.inProgress, .free])
        XCTAssertEqual(model.groups[0].items.map(\.title), ["Book the vet", "Pick up the parcel"])
        XCTAssertEqual(model.groups[1].items.map(\.title), ["Buy milk", "Water the plants"])
    }

    func testDoneTasksStayOutOfTheList() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)

        XCTAssertFalse(model.items.contains { $0.title == "Take out the bins" })
    }

    func testFolderTasksStayOutOfTheAllList() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)

        XCTAssertFalse(model.items.contains { $0.title == "Coffee" })
        XCTAssertEqual(model.counts.all, 4)
    }

    func testFilterKeepsOnlyTheChosenOwner() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)

        model.filter = .mine
        XCTAssertEqual(model.groups.map(\.kind), [.inProgress])
        XCTAssertEqual(model.groups[0].items.map(\.title), ["Book the vet"])

        model.filter = .partner
        XCTAssertEqual(model.groups[0].items.map(\.title), ["Pick up the parcel"])

        model.filter = .free
        XCTAssertEqual(model.groups.map(\.kind), [.free])
        XCTAssertEqual(model.groups[0].items.count, 2)
    }

    func testPartnerFilterIsHiddenWithoutAPartner() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        var context = fixture.context
        context.partnerId = nil
        context.partnerName = nil
        await model.apply(context)

        XCTAssertEqual(model.availableFilters, [.all, .mine, .free])
        XCTAssertEqual(model.counts.partner, 0)
        XCTAssertEqual(model.count(for: .all), 4)
    }

    func testSelectedFilterFallsBackWhenThePartnerLeaves() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)
        model.filter = .partner

        var context = fixture.context
        context.partnerId = nil
        context.partnerName = nil
        await model.apply(context)

        XCTAssertEqual(model.filter, .all)
    }

    func testTakeMovesAFreeTaskIntoInProgress() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)
        let free = try XCTUnwrap(model.items.first { $0.title == "Buy milk" })

        await model.take(free)

        XCTAssertEqual(model.counts.mine, 2)
        XCTAssertEqual(model.counts.free, 1)
        model.filter = .mine
        XCTAssertEqual(model.groups[0].items.map(\.title), ["Book the vet", "Buy milk"])
        XCTAssertEqual(fixture.analytics.names, ["task_taken"])
    }

    func testHandBackReturnsATaskToFree() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)
        let mine = try XCTUnwrap(model.items.first { $0.title == "Book the vet" })

        await model.handBack(mine)

        XCTAssertEqual(model.counts.mine, 0)
        XCTAssertEqual(model.counts.free, 3)
        XCTAssertEqual(fixture.analytics.names, ["task_handed_back"])
    }

    func testMarkDoneDropsTheTaskAndKeepsTheCountsInSync() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)
        let mine = try XCTUnwrap(model.items.first { $0.title == "Book the vet" })

        await model.toggleDone(mine)

        XCTAssertEqual(model.counts.all, 3)
        XCTAssertEqual(model.counts.mine, 0)
        XCTAssertFalse(model.items.contains { $0.id == mine.id })
        XCTAssertEqual(fixture.analytics.names, ["task_done"])
    }

    func testMarkDoneOnARecurringTaskCreatesTheNextOccurrence() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)
        let repeating = try XCTUnwrap(model.items.first { $0.title == "Water the plants" })

        await model.toggleDone(repeating)

        let next = try XCTUnwrap(model.items.first { $0.title == "Water the plants" }?.task)
        XCTAssertNotEqual(next.id, repeating.id)
        XCTAssertEqual(next.recurrence, .daily)
        XCTAssertNil(next.assigneeMemberId)
        let dueAt = try XCTUnwrap(next.dueAt)
        let previousDueAt = try XCTUnwrap(repeating.task?.dueAt)
        XCTAssertGreaterThan(dueAt, previousDueAt)
        XCTAssertEqual(model.counts.all, 4)
    }

    func testDeleteRemovesTheTask() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)
        let free = try XCTUnwrap(model.items.first { $0.title == "Buy milk" })

        await model.delete(free)

        XCTAssertEqual(model.counts.all, 3)
        XCTAssertEqual(model.counts.free, 1)
    }

    func testOnlyTheAuthorCanDelete() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)

        let mine = try XCTUnwrap(model.items.first { $0.title == "Book the vet" })
        let theirs = try XCTUnwrap(model.items.first { $0.title == "Pick up the parcel" })

        XCTAssertTrue(model.canDelete(mine))
        XCTAssertFalse(model.canDelete(theirs))
    }

    func testADatedGoalStepJoinsTheListAndTicksBackIntoTheStep() async throws {
        let fixture = try await makeFixture()
        let goal = try await fixture.controller.repositories.goals.create(
            GoalDraft(spaceId: fixture.space.id, title: "Japan", createdByMemberId: fixture.me.id)
        )
        let step = try await fixture.controller.repositories.goals.addStep(
            goalId: goal.id,
            draft: GoalStepDraft(title: "Renew the passport", assigneeMemberId: fixture.me.id, dueAt: now)
        )
        _ = try await fixture.controller.repositories.goals.addStep(
            goalId: goal.id,
            draft: GoalStepDraft(title: "Pick the hotel")
        )

        let model = fixture.makeModel()
        await model.apply(fixture.context)

        let row = try XCTUnwrap(model.items.first { $0.id == step.id })
        XCTAssertEqual(row.goalTitle, "Japan")
        XCTAssertNil(row.task)
        XCTAssertEqual(model.counts.all, 5)
        XCTAssertEqual(model.counts.mine, 2)
        XCTAssertFalse(model.items.contains { $0.title == "Pick the hotel" })

        await model.toggleDone(row)

        let stored = try await fixture.controller.repositories.goals.steps(goalId: goal.id)
        let ticked = try XCTUnwrap(stored.first { $0.id == step.id })
        XCTAssertTrue(ticked.isDone)
        XCTAssertEqual(ticked.doneByMemberId, fixture.me.id)
        XCTAssertFalse(model.items.contains { $0.id == step.id })
        XCTAssertEqual(fixture.analytics.names, ["goal_step_done"])
    }

    func testAGoalStepCannotBeTakenOrDeleted() async throws {
        let fixture = try await makeFixture()
        let goal = try await fixture.controller.repositories.goals.create(
            GoalDraft(spaceId: fixture.space.id, title: "Japan", createdByMemberId: fixture.me.id)
        )
        let step = try await fixture.controller.repositories.goals.addStep(
            goalId: goal.id,
            draft: GoalStepDraft(title: "Book the flights", dueAt: now)
        )
        let model = fixture.makeModel()
        await model.apply(fixture.context)
        let row = try XCTUnwrap(model.items.first { $0.id == step.id })

        XCTAssertTrue(row.isFree)
        XCTAssertFalse(model.canDelete(row))

        await model.take(row)
        await model.delete(row)

        XCTAssertTrue(model.items.contains { $0.id == step.id })
        XCTAssertTrue(fixture.analytics.names.isEmpty)
    }

    private func makeFixture() async throws -> TasksFixture {
        try await TasksFixture.make(now: now)
    }
}

@MainActor
struct TasksFixture {
    let controller: PersistenceController
    let space: SpaceDTO
    let me: MemberDTO
    let partner: MemberDTO
    let shopping: TaskFolderDTO
    let now: Date
    let analytics = TasksRecordingAnalytics()

    var context: TasksContext {
        TasksContext(
            spaceId: space.id,
            memberId: me.id,
            partnerId: partner.id,
            partnerName: partner.displayName,
            prefs: me.notificationPrefs
        )
    }

    func makeModel() -> TasksViewModel {
        let stamp = now
        return TasksViewModel(
            repository: controller.repositories.tasks,
            provider: UnifiedTaskProvider(repositories: controller.repositories),
            notifications: TaskDueNotifications(
                scheduler: NotificationScheduler(client: PreviewNotificationClient())
            ),
            analytics: analytics,
            now: { stamp }
        )
    }

    static func make(now: Date) async throws -> TasksFixture {
        let controller = PersistenceController.inMemory()
        let repositories = controller.repositories
        let space = try await repositories.spaces.create(displayCurrency: "USD", creatorMemberId: nil, now: now)
        let me = try await repositories.members.upsertCurrentMember(
            appleUserId: "tests.me",
            spaceId: space.id,
            draft: MemberDraft(displayName: "Ilya", colorKey: MemberColorKey.p1.rawValue)
        )
        let partner = try await repositories.members.upsertCurrentMember(
            appleUserId: "tests.partner",
            spaceId: space.id,
            draft: MemberDraft(displayName: "Sofia", colorKey: MemberColorKey.p2.rawValue)
        )

        _ = try await repositories.tasks.create(
            TaskDraft(
                spaceId: space.id,
                title: "Book the vet",
                assigneeMemberId: me.id,
                dueAt: now,
                createdByMemberId: me.id
            )
        )
        _ = try await repositories.tasks.create(
            TaskDraft(
                spaceId: space.id,
                title: "Pick up the parcel",
                assigneeMemberId: partner.id,
                dueAt: now.addingTimeInterval(86_400),
                createdByMemberId: partner.id
            )
        )
        _ = try await repositories.tasks.create(
            TaskDraft(
                spaceId: space.id,
                title: "Buy milk",
                dueAt: now.addingTimeInterval(2 * 86_400),
                createdByMemberId: me.id
            )
        )
        _ = try await repositories.tasks.create(
            TaskDraft(
                spaceId: space.id,
                title: "Water the plants",
                dueAt: now.addingTimeInterval(3 * 86_400),
                recurrence: .daily,
                createdByMemberId: me.id
            )
        )
        let done = try await repositories.tasks.create(
            TaskDraft(
                spaceId: space.id,
                title: "Take out the bins",
                assigneeMemberId: me.id,
                createdByMemberId: me.id
            )
        )
        _ = try await repositories.tasks.markDone(taskId: done.id, memberId: me.id, at: now)

        let shopping = try await repositories.tasks.pinnedShoppingFolder(
            spaceId: space.id,
            title: "Shopping",
            createdByMemberId: me.id
        )
        _ = try await repositories.tasks.create(
            TaskDraft(spaceId: space.id, title: "Coffee", folderId: shopping.id, createdByMemberId: partner.id)
        )

        return TasksFixture(controller: controller, space: space, me: me, partner: partner, shopping: shopping, now: now)
    }
}

final class TasksRecordingAnalytics: AnalyticsRecording, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [AnalyticsEvent] = []

    var names: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded.map(\.name)
    }

    var events: [AnalyticsEvent] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func record(_ event: AnalyticsEvent) {
        lock.lock()
        recorded.append(event)
        lock.unlock()
    }
}
