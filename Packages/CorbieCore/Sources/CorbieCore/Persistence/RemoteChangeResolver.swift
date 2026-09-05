import CoreData
import Foundation

public struct RemoteChangeResolver: Sendable {
    private let stack: CoreDataStack

    public init(stack: CoreDataStack) {
        self.stack = stack
    }

    public func changes(for records: [RemoteChangeRecord], spaceId: UUID) async -> [RemoteChange] {
        let candidates = records.filter { $0.isFromAnotherDevice && $0.type != .delete }
        guard candidates.isEmpty == false else { return [] }
        let context = stack.newBackgroundContext()
        let coordinator = stack.container.persistentStoreCoordinator
        return await context.perform {
            candidates.compactMap { record in
                guard let objectId = coordinator.managedObjectID(forURIRepresentation: record.objectURI),
                      let object = try? context.existingObject(with: objectId),
                      let subject = RemoteChangeResolver.subject(of: object, spaceId: spaceId)
                else { return nil }
                return RemoteChange(type: record.type, properties: record.properties, subject: subject)
            }
        }
    }

    static func subject(of object: NSManagedObject, spaceId: UUID) -> RemoteChangeSubject? {
        switch object {
        case let task as TaskItem:
            guard task.space?.id == spaceId else { return nil }
            return .task(TaskDTO(task))
        case let wish as Wish:
            guard wish.space?.id == spaceId else { return nil }
            return .wish(WishDTO(wish))
        case let plan as Plan:
            guard plan.space?.id == spaceId else { return nil }
            return .plan(PlanDTO(plan))
        case let expense as PlanExpense:
            guard let plan = expense.plan, plan.space?.id == spaceId else { return nil }
            return .expense(PlanExpenseDTO(expense), plan: PlanDTO(plan))
        case let open as CapsuleOpen:
            guard let capsule = open.capsule, capsule.space?.id == spaceId else { return nil }
            return .capsuleOpen(capsule: CapsuleDTO(capsule), memberId: open.memberId)
        case let vote as Vote:
            guard vote.space?.id == spaceId else { return nil }
            return .vote(VoteDTO(vote))
        default:
            return nil
        }
    }
}
