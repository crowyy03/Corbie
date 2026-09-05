import CoreData
import Foundation

public final class PersistenceController: Sendable {
    public static let shared = PersistenceController(stack: CoreDataStack(author: .app))
    public static let preview = PersistenceController(stack: CoreDataStack(inMemoryAuthor: .tests))

    public let stack: CoreDataStack
    public let repositories: Repositories

    public init(stack: CoreDataStack) {
        self.stack = stack
        repositories = Repositories(stack: stack)
    }

    public static func inMemory(author: TransactionAuthor = .tests) -> PersistenceController {
        PersistenceController(stack: CoreDataStack(inMemoryAuthor: author))
    }

    public static func cloudKit(author: TransactionAuthor) -> PersistenceController {
        PersistenceController(stack: CoreDataStack(author: author))
    }

    public var viewContext: NSManagedObjectContext { stack.viewContext }
}
