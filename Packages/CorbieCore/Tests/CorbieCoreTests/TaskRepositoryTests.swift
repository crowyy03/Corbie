import Foundation
import Testing
@testable import CorbieCore

@Suite struct TaskRepositoryTests {
    @Test func createTakeAndHandBack() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.tasks
        let task = try await repository.create(
            TaskDraft(spaceId: world.space.id, title: "Book the table", createdByMemberId: world.me.id)
        )
        #expect(task.isFree)
        #expect(task.takenAt == nil)

        let taken = try await repository.take(taskId: task.id, memberId: world.me.id)
        #expect(taken.assigneeMemberId == world.me.id)
        #expect(taken.takenAt != nil)

        let free = try await repository.handBack(taskId: task.id)
        #expect(free.isFree)
        #expect(free.takenAt != nil)
    }

    @Test func emptyTitleIsRejected() async throws {
        let world = try await TestWorld.make()
        await #expect(throws: CorbieError.invalidInput("task title is empty")) {
            _ = try await world.repositories.tasks.create(TaskDraft(spaceId: world.space.id, title: "   "))
        }
    }

    @Test func filtersSplitMineFreeAndDone() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.tasks
        let spaceId = world.space.id
        _ = try await repository.create(
            TaskDraft(spaceId: spaceId, title: "Mine", assigneeMemberId: world.me.id)
        )
        _ = try await repository.create(
            TaskDraft(spaceId: spaceId, title: "Theirs", assigneeMemberId: world.partner.id)
        )
        let free = try await repository.create(TaskDraft(spaceId: spaceId, title: "Free"))
        let done = try await repository.create(
            TaskDraft(spaceId: spaceId, title: "Done", assigneeMemberId: world.me.id)
        )
        _ = try await repository.markDone(taskId: done.id, memberId: world.me.id)

        let all = try await repository.tasks(TaskQuery(spaceId: spaceId))
        #expect(all.count == 3)

        let mine = try await repository.tasks(TaskQuery(spaceId: spaceId, assignee: .member(world.me.id)))
        #expect(mine.map(\.title) == ["Mine"])

        let freeOnly = try await repository.tasks(TaskQuery(spaceId: spaceId, assignee: .free))
        #expect(freeOnly.map(\.id) == [free.id])

        let doneOnly = try await repository.tasks(TaskQuery(spaceId: spaceId, done: .done))
        #expect(doneOnly.map(\.title) == ["Done"])

        let counts = try await repository.counts(spaceId: spaceId, memberId: world.me.id)
        #expect(counts == TaskCounts(all: 3, mine: 1, partner: 1, free: 1))
    }

    @Test func markingDoneRecordsWhoAndWhen() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.tasks
        let task = try await repository.create(TaskDraft(spaceId: world.space.id, title: "Water the plants"))
        let at = Date(timeIntervalSince1970: 1_757_000_000)
        let completion = try await repository.markDone(taskId: task.id, memberId: world.partner.id, at: at)
        #expect(completion.task.isDone)
        #expect(completion.task.doneByMemberId == world.partner.id)
        #expect(completion.task.doneAt == at)
        #expect(completion.isNextOccurrenceDue == false)
    }

    @Test func recurringTaskReportsAndCreatesNextOccurrence() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.tasks
        let due = Date(timeIntervalSince1970: 1_757_000_000)
        let task = try await repository.create(
            TaskDraft(
                spaceId: world.space.id,
                title: "Take out the bins",
                assigneeMemberId: world.me.id,
                dueAt: due,
                recurrence: .weekly,
                createdByMemberId: world.me.id
            )
        )
        let completion = try await repository.markDone(taskId: task.id, memberId: world.me.id, at: due)
        let expected = Calendar.utc.date(byAdding: .weekOfYear, value: 1, to: due)
        #expect(completion.isNextOccurrenceDue)
        #expect(completion.nextOccurrenceDueAt == expected)

        let next = try await repository.createNextOccurrence(of: task.id, dueAt: completion.nextOccurrenceDueAt)
        #expect(next.title == task.title)
        #expect(next.dueAt == expected)
        #expect(next.isDone == false)
        #expect(next.recurrence == .weekly)
        #expect(next.assigneeMemberId == world.me.id)

        let open = try await repository.tasks(TaskQuery(spaceId: world.space.id))
        #expect(open.count == 1)
    }

    @Test func deleteRemovesTheTask() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.tasks
        let task = try await repository.create(TaskDraft(spaceId: world.space.id, title: "Temporary"))
        try await repository.delete(id: task.id)
        #expect(try await repository.task(id: task.id) == nil)
    }

    @Test func writesAskForAWidgetReload() async throws {
        let world = try await TestWorld.make()
        let counter = ReloadCounter()
        let token = NotificationCenter.default.addObserver(
            forName: WidgetReloadRequest.notificationName,
            object: nil,
            queue: nil
        ) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }

        _ = try await world.repositories.tasks.create(TaskDraft(spaceId: world.space.id, title: "Reload me"))
        #expect(counter.count >= 1)
    }
}
