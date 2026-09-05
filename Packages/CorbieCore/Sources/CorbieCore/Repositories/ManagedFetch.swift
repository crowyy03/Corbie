import CoreData
import Foundation

enum ManagedFetch {
    static func request<T: NSManagedObject>(
        _ entityName: String,
        predicate: NSPredicate? = nil,
        sort: [NSSortDescriptor] = [],
        limit: Int = 0
    ) -> NSFetchRequest<T> {
        let request = NSFetchRequest<T>(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sort
        request.fetchLimit = limit
        return request
    }

    static func all<T: NSManagedObject>(
        _ entityName: String,
        predicate: NSPredicate? = nil,
        sort: [NSSortDescriptor] = [],
        in context: NSManagedObjectContext
    ) throws -> [T] {
        try context.fetch(request(entityName, predicate: predicate, sort: sort))
    }

    static func first<T: NSManagedObject>(
        _ entityName: String,
        id: UUID,
        in context: NSManagedObjectContext
    ) throws -> T? {
        let predicate = NSPredicate(format: "id == %@", id as NSUUID)
        let fetch: NSFetchRequest<T> = request(entityName, predicate: predicate, limit: 1)
        return try context.fetch(fetch).first
    }

    static func require<T: NSManagedObject>(
        _ entityName: String,
        id: UUID,
        in context: NSManagedObjectContext
    ) throws -> T {
        guard let object: T = try first(entityName, id: id, in: context) else {
            throw CorbieError.notFound("\(entityName) \(id)")
        }
        return object
    }

    static func spaceRelation(_ spaceId: UUID) -> NSPredicate {
        NSPredicate(format: "space.id == %@", spaceId as NSUUID)
    }
}
