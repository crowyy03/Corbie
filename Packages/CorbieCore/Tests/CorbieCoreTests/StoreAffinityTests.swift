import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct StoreAffinityTests {
    @Test func everyChildOfAJoinedSpaceLandsInTheSharedStore() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = PersistenceController(stack: CoreDataStack(storesIn: directory))
        let stack = controller.stack
        #expect(stack.loadFailure == nil)
        #expect(stack.container.persistentStoreCoordinator.persistentStores.count == 2)

        let shared = try #require(stack.store(for: .sharedStore))
        let privateStore = try #require(stack.store(for: .privateStore))
        #expect(shared !== privateStore)

        let spaceId = try insertSpace(into: shared, stack: stack)
        let repositories = controller.repositories

        let member = try await repositories.members.upsertCurrentMember(
            appleUserId: "apple-partner",
            spaceId: spaceId,
            draft: MemberDraft(displayName: "Sofia")
        )
        let task = try await repositories.tasks.create(TaskDraft(spaceId: spaceId, title: "Book the table"))
        let event = try await repositories.events.create(
            EventDraft(spaceId: spaceId, title: "Dinner", startAt: Date())
        )
        let wish = try await repositories.wishes.create(
            WishDraft(spaceId: spaceId, ownerMemberId: member.id, title: "Lamp")
        )
        let plan = try await repositories.plans.create(
            PlanDraft(spaceId: spaceId, title: "Lisbon", targetAmount: 1000, currency: "USD")
        )
        let list = try await repositories.lists.create(ChecklistDraft(spaceId: spaceId, title: "Cities"))
        let person = try await repositories.people.create(PersonDraft(spaceId: spaceId, name: "Anna"))

        let comment = try await repositories.events.addComment(
            eventId: event.id,
            memberId: member.id,
            text: "Table for two"
        )
        let expense = try await repositories.plans.addExpense(
            planId: plan.id,
            draft: ExpenseDraft(amount: 120, currency: "USD")
        )
        let item = try await repositories.lists.addItem(listId: list.id, draft: ListItemDraft(title: "Porto"))
        let idea = try await repositories.people.addGiftIdea(personId: person.id, draft: GiftIdeaDraft(title: "Book"))

        let expected: [(String, UUID)] = [
            (Space.entityName, spaceId),
            (Member.entityName, member.id),
            (TaskItem.entityName, task.id),
            (Event.entityName, event.id),
            (Wish.entityName, wish.id),
            (Plan.entityName, plan.id),
            (ChecklistList.entityName, list.id),
            (Person.entityName, person.id),
            (EventComment.entityName, comment.id),
            (PlanExpense.entityName, expense.id),
            (ListItem.entityName, item.id),
            (GiftIdea.entityName, idea.id)
        ]
        for (entityName, id) in expected {
            #expect(try store(of: entityName, id: id, stack: stack) === shared, "\(entityName) is in the wrong store")
        }
    }

    @Test func aSpaceCreatedHereGoesToThePrivateStore() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = PersistenceController(stack: CoreDataStack(storesIn: directory))
        let space = try await controller.repositories.spaces.create(displayCurrency: "USD")
        let privateStore = try #require(controller.stack.store(for: .privateStore))
        #expect(try store(of: Space.entityName, id: space.id, stack: controller.stack) === privateStore)
    }

    @Test func aScopeWithoutItsFileHasNoStore() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let stack = CoreDataStack(storesIn: directory)
        #expect(stack.store(for: .privateStore) !== stack.store(for: .sharedStore))
        let inMemory = CoreDataStack(inMemoryAuthor: .tests)
        #expect(inMemory.store(for: .privateStore) != nil)
    }

    private func makeDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-stores-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func insertSpace(into store: NSPersistentStore, stack: CoreDataStack) throws -> UUID {
        let context = stack.newBackgroundContext()
        return try context.performAndWait {
            let space = Space(context: context)
            context.assign(space, to: store)
            space.displayCurrency = "USD"
            try context.save()
            return try #require(space.id)
        }
    }

    private func store(of entityName: String, id: UUID, stack: CoreDataStack) throws -> NSPersistentStore? {
        let context = stack.newBackgroundContext()
        return try context.performAndWait {
            let object: NSManagedObject = try ManagedFetch.require(entityName, id: id, in: context)
            return object.objectID.persistentStore
        }
    }
}
