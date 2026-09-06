import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainUnifiedTaskTests {
    private let day = Date(timeIntervalSince1970: 1_800_000_000)

    private struct World {
        let test: TestWorld
        let provider: UnifiedTaskProvider
        let goal: GoalDTO
    }

    private func makeWorld() async throws -> World {
        let test = try await TestWorld.make()
        let goal = try await test.repositories.goals.create(
            GoalDraft(spaceId: test.space.id, title: "Japan", targetAmount: 4000, currency: "USD")
        )
        return World(
            test: test,
            provider: UnifiedTaskProvider(repositories: test.repositories),
            goal: goal
        )
    }

    @Test func datedGoalStepsJoinPlainTasksInDueDateOrder() async throws {
        let world = try await makeWorld()
        let repositories = world.test.repositories
        _ = try await repositories.tasks.create(
            TaskDraft(spaceId: world.test.space.id, title: "Book the vet", dueAt: day.addingTimeInterval(7200))
        )
        _ = try await repositories.goals.addStep(
            goalId: world.goal.id,
            draft: GoalStepDraft(title: "Renew the passport", dueAt: day)
        )
        _ = try await repositories.goals.addStep(
            goalId: world.goal.id,
            draft: GoalStepDraft(title: "Buy an adapter")
        )

        let items = try await world.provider.unifiedTasks(TaskQuery(spaceId: world.test.space.id))
        #expect(items.map(\.title) == ["Renew the passport", "Book the vet"])
        #expect(items.first?.source == .goalStep(goalTitle: "Japan"))
        #expect(items.first?.goalTitle == "Japan")
        #expect(items.last?.source == .task)
        #expect(items.last?.goalTitle == nil)
    }

    @Test func folderTasksAndFolderQueriesStayOutOfTheUnifiedList() async throws {
        let world = try await makeWorld()
        let repositories = world.test.repositories
        let folder = try await repositories.tasks.createFolder(
            TaskFolderDraft(spaceId: world.test.space.id, title: "Shopping", template: .shopping)
        )
        _ = try await repositories.tasks.create(
            TaskDraft(spaceId: world.test.space.id, title: "Milk", folderId: folder.id)
        )
        _ = try await repositories.tasks.create(TaskDraft(spaceId: world.test.space.id, title: "Call the vet"))
        _ = try await repositories.goals.addStep(
            goalId: world.goal.id,
            draft: GoalStepDraft(title: "Renew the passport", dueAt: day)
        )

        let plain = try await world.provider.unifiedTasks(TaskQuery(spaceId: world.test.space.id))
        #expect(plain.map(\.title) == ["Renew the passport", "Call the vet"])

        let inFolder = try await world.provider.unifiedTasks(
            TaskQuery(spaceId: world.test.space.id, folder: .folder(folder.id))
        )
        #expect(inFolder.map(\.title) == ["Milk"])
    }

    @Test func theAssigneeFilterAppliesToStepsToo() async throws {
        let world = try await makeWorld()
        let repositories = world.test.repositories
        _ = try await repositories.goals.addStep(
            goalId: world.goal.id,
            draft: GoalStepDraft(title: "Mine", assigneeMemberId: world.test.me.id, dueAt: day)
        )
        _ = try await repositories.goals.addStep(
            goalId: world.goal.id,
            draft: GoalStepDraft(title: "Nobody's", dueAt: day.addingTimeInterval(60))
        )
        _ = try await repositories.tasks.create(
            TaskDraft(
                spaceId: world.test.space.id,
                title: "My task",
                assigneeMemberId: world.test.me.id,
                dueAt: day.addingTimeInterval(120)
            )
        )

        let mine = try await world.provider.unifiedTasks(
            TaskQuery(spaceId: world.test.space.id, assignee: .member(world.test.me.id))
        )
        #expect(mine.map(\.title) == ["Mine", "My task"])

        let free = try await world.provider.unifiedTasks(
            TaskQuery(spaceId: world.test.space.id, assignee: .free)
        )
        #expect(free.map(\.title) == ["Nobody's"])
        #expect(free.allSatisfy { $0.isFree })
    }

    @Test func togglingWritesBackToTheRepositoryTheItemCameFrom() async throws {
        let world = try await makeWorld()
        let repositories = world.test.repositories
        let task = try await repositories.tasks.create(
            TaskDraft(spaceId: world.test.space.id, title: "Book the vet", dueAt: day.addingTimeInterval(7200))
        )
        let step = try await repositories.goals.addStep(
            goalId: world.goal.id,
            draft: GoalStepDraft(title: "Renew the passport", dueAt: day)
        )
        let items = try await world.provider.unifiedTasks(TaskQuery(spaceId: world.test.space.id))

        let doneStep = try await world.provider.toggleDone(try #require(items.first), by: world.test.me.id, at: day)
        #expect(doneStep.isDone)
        let storedSteps = try await repositories.goals.steps(goalId: world.goal.id)
        #expect(storedSteps.first?.isDone == true)

        let doneTask = try await world.provider.toggleDone(try #require(items.last), by: world.test.me.id, at: day)
        #expect(doneTask.isDone)
        let storedTask = try await repositories.tasks.task(id: task.id)
        #expect(storedTask?.doneByMemberId == world.test.me.id)

        let open = try await world.provider.unifiedTasks(TaskQuery(spaceId: world.test.space.id))
        #expect(open.isEmpty)

        let closed = try await world.provider.unifiedTasks(
            TaskQuery(spaceId: world.test.space.id, done: .done)
        )
        let closedIds = Set(closed.map(\.id))
        #expect(closedIds == Set([step.id, task.id]))
    }

    @Test func untickingATaskThroughTheProviderClearsWhoDidIt() async throws {
        let world = try await makeWorld()
        let repositories = world.test.repositories
        let task = try await repositories.tasks.create(
            TaskDraft(spaceId: world.test.space.id, title: "Book the vet")
        )
        _ = try await repositories.tasks.markDone(taskId: task.id, memberId: world.test.me.id, at: day)
        let done = try await world.provider.unifiedTasks(
            TaskQuery(spaceId: world.test.space.id, done: .done)
        )
        let reopened = try await world.provider.toggleDone(try #require(done.first), by: world.test.me.id, at: day)
        #expect(reopened.isDone == false)
        let stored = try await repositories.tasks.task(id: task.id)
        #expect(stored?.doneByMemberId == nil)
        #expect(stored?.doneAt == nil)
    }
}
