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
        XCTAssertEqual(model.groups[0].tasks.map(\.title), ["Book the vet", "Pick up the parcel"])
        XCTAssertEqual(model.groups[1].tasks.map(\.title), ["Buy milk", "Water the plants"])
    }

    func testDoneTasksStayOutOfTheList() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)

        XCTAssertFalse(model.tasks.contains { $0.title == "Take out the bins" })
    }

    func testFilterKeepsOnlyTheChosenOwner() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)

        model.filter = .mine
        XCTAssertEqual(model.groups.map(\.kind), [.inProgress])
        XCTAssertEqual(model.groups[0].tasks.map(\.title), ["Book the vet"])

        model.filter = .partner
        XCTAssertEqual(model.groups[0].tasks.map(\.title), ["Pick up the parcel"])

        model.filter = .free
        XCTAssertEqual(model.groups.map(\.kind), [.free])
        XCTAssertEqual(model.groups[0].tasks.count, 2)
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
        let free = try XCTUnwrap(model.tasks.first { $0.title == "Buy milk" })

        await model.take(free)

        XCTAssertEqual(model.counts.mine, 2)
        XCTAssertEqual(model.counts.free, 1)
        model.filter = .mine
        XCTAssertEqual(model.groups[0].tasks.map(\.title), ["Book the vet", "Buy milk"])
        XCTAssertEqual(fixture.analytics.names, ["task_taken"])
    }

    func testHandBackReturnsATaskToFree() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)
        let mine = try XCTUnwrap(model.tasks.first { $0.title == "Book the vet" })

        await model.handBack(mine)

        XCTAssertEqual(model.counts.mine, 0)
        XCTAssertEqual(model.counts.free, 3)
        XCTAssertEqual(fixture.analytics.names, ["task_handed_back"])
    }

    func testMarkDoneDropsTheTaskAndKeepsTheCountsInSync() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)
        let mine = try XCTUnwrap(model.tasks.first { $0.title == "Book the vet" })

        await model.markDone(mine)

        XCTAssertEqual(model.counts.all, 3)
        XCTAssertEqual(model.counts.mine, 0)
        XCTAssertFalse(model.tasks.contains { $0.id == mine.id })
        XCTAssertEqual(fixture.analytics.names, ["task_done"])
    }

    func testMarkDoneOnARecurringTaskCreatesTheNextOccurrence() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)
        let repeating = try XCTUnwrap(model.tasks.first { $0.title == "Water the plants" })

        await model.markDone(repeating)

        let next = try XCTUnwrap(model.tasks.first { $0.title == "Water the plants" })
        XCTAssertNotEqual(next.id, repeating.id)
        XCTAssertEqual(next.recurrence, .daily)
        XCTAssertNil(next.assigneeMemberId)
        let dueAt = try XCTUnwrap(next.dueAt)
        let previousDueAt = try XCTUnwrap(repeating.dueAt)
        XCTAssertGreaterThan(dueAt, previousDueAt)
        XCTAssertEqual(model.counts.all, 4)
    }

    func testDeleteRemovesTheTask() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)
        let free = try XCTUnwrap(model.tasks.first { $0.title == "Buy milk" })

        await model.delete(free)

        XCTAssertEqual(model.counts.all, 3)
        XCTAssertEqual(model.counts.free, 1)
    }

    func testOnlyTheAuthorCanDelete() async throws {
        let fixture = try await makeFixture()
        let model = fixture.makeModel()
        await model.apply(fixture.context)

        let mine = try XCTUnwrap(model.tasks.first { $0.title == "Book the vet" })
        let theirs = try XCTUnwrap(model.tasks.first { $0.title == "Pick up the parcel" })

        XCTAssertTrue(model.canDelete(mine))
        XCTAssertFalse(model.canDelete(theirs))
    }

    private func makeFixture() async throws -> Fixture {
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

        return Fixture(controller: controller, space: space, me: me, partner: partner, now: now)
    }
}

@MainActor
private struct Fixture {
    let controller: PersistenceController
    let space: SpaceDTO
    let me: MemberDTO
    let partner: MemberDTO
    let now: Date
    let analytics = RecordingAnalytics()

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
            notifications: TaskDueNotifications(
                scheduler: NotificationScheduler(client: PreviewNotificationClient())
            ),
            analytics: analytics,
            now: { stamp }
        )
    }
}

private final class RecordingAnalytics: AnalyticsRecording, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []

    var names: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func record(_ event: AnalyticsEvent) {
        lock.lock()
        recorded.append(event.name)
        lock.unlock()
    }
}
