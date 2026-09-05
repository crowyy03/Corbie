import CoreData
import Foundation

struct CoreDataAccess: Sendable {
    let stack: CoreDataStack

    func read<T: Sendable>(_ body: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        try await run(body)
    }

    func write<T: Sendable>(_ body: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        let value = try await run { context in
            let result = try body(context)
            if context.hasChanges {
                try context.save()
            }
            return result
        }
        WidgetReloadRequest.post()
        return value
    }

    private func run<T: Sendable>(_ body: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = stack.newBackgroundContext()
        do {
            return try await context.perform { try body(context) }
        } catch let error as CorbieError {
            throw error
        } catch {
            throw CorbieError.persistence(error.localizedDescription)
        }
    }
}
