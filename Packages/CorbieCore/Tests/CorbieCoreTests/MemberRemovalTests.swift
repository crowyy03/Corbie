import Foundation
import Testing
@testable import CorbieCore

@Suite struct MemberRemovalTests {
    @Test func removingAMemberFreesTheirTasksAndPlanSteps() async throws {
        let world = try await TestWorld.make()
        let repositories = world.repositories
        let spaceId = world.space.id
        let theirs = try await repositories.tasks.create(
            TaskDraft(spaceId: spaceId, title: "Call the bank", assigneeMemberId: world.partner.id)
        )
        let mine = try await repositories.tasks.create(
            TaskDraft(spaceId: spaceId, title: "Buy milk", assigneeMemberId: world.me.id)
        )
        let plan = try await repositories.plans.create(PlanDraft(spaceId: spaceId, title: "Lisbon"))
        let theirStep = try await repositories.plans.addStep(
            planId: plan.id,
            draft: PlanStepDraft(title: "Book flights", assigneeMemberId: world.partner.id)
        )
        let myStep = try await repositories.plans.addStep(
            planId: plan.id,
            draft: PlanStepDraft(title: "Pack", assigneeMemberId: world.me.id)
        )

        let removed = try await repositories.members.removeMembersAndFreeTheirTasks(
            ids: [world.partner.id],
            spaceId: spaceId
        )

        #expect(removed == 1)
        #expect(try await repositories.members.members(spaceId: spaceId).map(\.id) == [world.me.id])
        #expect(try await repositories.members.partner(of: world.me.id, spaceId: spaceId) == nil)
        #expect(try await repositories.tasks.task(id: theirs.id)?.assigneeMemberId == nil)
        #expect(try await repositories.tasks.task(id: mine.id)?.assigneeMemberId == world.me.id)
        let steps = try await repositories.plans.steps(planId: plan.id)
        #expect(steps.first { $0.id == theirStep.id }?.assigneeMemberId == nil)
        #expect(steps.first { $0.id == myStep.id }?.assigneeMemberId == world.me.id)
    }

    @Test func aMemberOfAnotherSpaceIsLeftAlone() async throws {
        let world = try await TestWorld.make()
        let repositories = world.repositories
        let task = try await repositories.tasks.create(
            TaskDraft(spaceId: world.space.id, title: "Call the bank", assigneeMemberId: world.partner.id)
        )

        let removed = try await repositories.members.removeMembersAndFreeTheirTasks(
            ids: [world.partner.id, UUID()],
            spaceId: UUID()
        )

        #expect(removed == 0)
        #expect(try await repositories.members.members(spaceId: world.space.id).count == 2)
        #expect(try await repositories.tasks.task(id: task.id)?.assigneeMemberId == world.partner.id)
        #expect(try await repositories.members.removeMembersAndFreeTheirTasks(ids: [], spaceId: world.space.id) == 0)
    }
}
