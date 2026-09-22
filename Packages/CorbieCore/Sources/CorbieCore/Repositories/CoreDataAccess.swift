import CoreData
import Foundation

struct CoreDataAccess: Sendable {
    let stack: CoreDataStack

    func read<T: Sendable>(_ body: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        try await run(body)
    }

    func write<T: Sendable>(_ body: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        let (value, touched) = try await run { context in
            let result = try body(context)
            var touched: Set<String> = []
            if context.hasChanges {
                touched = StoreChange.pending(in: context)
                try context.save()
            }
            return (result, touched)
        }
        WidgetReloadRequest.post()
        stack.changes.post(StoreChange(origin: .thisProcess, entityNames: touched))
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
