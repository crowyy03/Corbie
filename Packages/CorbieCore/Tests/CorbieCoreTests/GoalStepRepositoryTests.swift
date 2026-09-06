import Foundation
import Testing
@testable import CorbieCore

@Suite struct GoalStepRepositoryTests {
    private func makeGoal(_ world: TestWorld) async throws -> GoalDTO {
        try await world.repositories.goals.create(
            GoalDraft(
                spaceId: world.space.id,
                title: "Wedding",
                targetAmount: 5000,
                currency: "USD",
                createdByMemberId: world.me.id
            )
        )
    }

    @Test func stepsKeepTheOrderTheyWereAddedIn() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.goals
        let goal = try await makeGoal(world)
        for title in ["Collect the papers", "Drop the child at the sitter", "Pick up the suit"] {
            _ = try await repository.addStep(goalId: goal.id, draft: GoalStepDraft(title: title))
        }
        let steps = try await repository.steps(goalId: goal.id)
        #expect(steps.map(\.sortIndex) == [0, 1, 2])
        #expect(steps.first?.title == "Collect the papers")
        #expect(steps.allSatisfy { $0.goalTitle == "Wedding" })
    }

    @Test func emptyStepTitleIsRejected() async throws {
        let world = try await TestWorld.make()
        let goal = try await makeGoal(world)
        await #expect(throws: CorbieError.invalidInput("goal step title is empty")) {
            _ = try await world.repositories.goals.addStep(goalId: goal.id, draft: GoalStepDraft(title: " "))
        }
    }

    @Test func togglingAStepRecordsWhoTickedItAndClearsOnUntick() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.goals
        let goal = try await makeGoal(world)
        let step = try await repository.addStep(goalId: goal.id, draft: GoalStepDraft(title: "Pack"))
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let done = try await repository.toggleStep(stepId: step.id, by: world.partner.id, at: now)
        #expect(done.isDone)
        #expect(done.doneByMemberId == world.partner.id)
        #expect(done.doneAt == now)

        let undone = try await repository.toggleStep(stepId: step.id, by: world.partner.id, at: now)
        #expect(undone.isDone == false)
        #expect(undone.doneByMemberId == nil)
        #expect(undone.doneAt == nil)
    }

    @Test func reorderingStepsRewritesEverySortIndex() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.goals
        let goal = try await makeGoal(world)
        let first = try await repository.addStep(goalId: goal.id, draft: GoalStepDraft(title: "One"))
        let second = try await repository.addStep(goalId: goal.id, draft: GoalStepDraft(title: "Two"))
        let third = try await repository.addStep(goalId: goal.id, draft: GoalStepDraft(title: "Three"))

        let reordered = try await repository.reorderSteps(goalId: goal.id, orderedStepIds: [third.id, first.id])
        #expect(reordered.map(\.title) == ["Three", "One", "Two"])
        #expect(reordered.map(\.sortIndex) == [0, 1, 2])
        #expect(reordered.last?.id == second.id)
    }

    @Test func onlyStepsWithADueDateReachTheSpaceWideList() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.goals
        let goal = try await makeGoal(world)
        let due = Date(timeIntervalSince1970: 1_800_000_000)
        _ = try await repository.addStep(goalId: goal.id, draft: GoalStepDraft(title: "No date"))
        _ = try await repository.addStep(
            goalId: goal.id,
            draft: GoalStepDraft(title: "Later", dueAt: due.addingTimeInterval(86_400))
        )
        _ = try await repository.addStep(goalId: goal.id, draft: GoalStepDraft(title: "Soon", dueAt: due))

        let dated = try await repository.datedSteps(spaceId: world.space.id)
        #expect(dated.map(\.title) == ["Soon", "Later"])
        #expect(dated.allSatisfy { $0.hasDue })
    }

    @Test func deletingAGoalTakesItsStepsAndTheCountsFollowTheTicks() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.goals
        let goal = try await makeGoal(world)
        let step = try await repository.addStep(goalId: goal.id, draft: GoalStepDraft(title: "Pack"))
        _ = try await repository.addStep(goalId: goal.id, draft: GoalStepDraft(title: "Print the tickets"))
        _ = try await repository.toggleStep(stepId: step.id, by: world.me.id)

        let stored = try #require(try await repository.goal(id: goal.id))
        #expect(stored.stepCount == 2)
        #expect(stored.doneStepCount == 1)

        try await repository.delete(id: goal.id)
        let orphans = try world.count(GoalStep.entityName)
        #expect(orphans == 0)
    }

    @Test func editingAStepKeepsItsIdentityAndDeletingRemovesOnlyIt() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.goals
        let goal = try await makeGoal(world)
        var step = try await repository.addStep(goalId: goal.id, draft: GoalStepDraft(title: "Pack"))
        _ = try await repository.addStep(goalId: goal.id, draft: GoalStepDraft(title: "Print the tickets"))

        step.title = "Pack the carry-on"
        step.assigneeMemberId = world.partner.id
        step.dueAt = Date(timeIntervalSince1970: 1_800_000_000)
        let updated = try await repository.updateStep(step)
        #expect(updated.id == step.id)
        #expect(updated.title == "Pack the carry-on")
        #expect(updated.assigneeMemberId == world.partner.id)

        try await repository.deleteStep(id: step.id)
        let left = try await repository.steps(goalId: goal.id)
        #expect(left.map(\.title) == ["Print the tickets"])
    }
}
