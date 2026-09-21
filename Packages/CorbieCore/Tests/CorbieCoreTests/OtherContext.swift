import CoreData
import Foundation
@testable import CorbieCore

enum OtherContext {
    static func change<Entity: NSManagedObject>(
        _ entityName: String,
        id: UUID,
        in controller: PersistenceController,
        _ body: @escaping (Entity) -> Void
    ) async throws {
        let context = controller.stack.newBackgroundContext()
        try await context.perform {
            let request = NSFetchRequest<Entity>(entityName: entityName)
            request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
            guard let object = try context.fetch(request).first else {
                throw CorbieError.notFound(entityName)
            }
            body(object)
            try context.save()
        }
    }

    static func overwrite(_ space: SpaceDTO, in controller: PersistenceController) async throws {
        try await change(Space.entityName, id: space.id, in: controller) { (stored: Space) in
            stored.togetherSince = space.togetherSince
            stored.weddingDate = space.weddingDate
            stored.displayCurrency = space.displayCurrency
            stored.anchorTimeZone = space.anchorTimeZone
            stored.creatorMemberId = space.creatorMemberId
            stored.subscriptionStatus = space.subscriptionStatus
            stored.subscriptionExpiresAt = space.subscriptionExpiresAt
            stored.subscriptionPayerMemberId = space.subscriptionPayerMemberId
        }
    }
}
