import CoreData
import Foundation

public final class PersistenceController: Sendable {
    public static let shared = PersistenceController(stack: CoreDataStack(appGroupAuthor: .app, mirroring: .cloudKit))
    #if DEBUG
    public static let preview = PersistenceController(stack: CoreDataStack(inMemoryAuthor: .tests))
    #endif

    public let stack: CoreDataStack
    public let repositories: Repositories
    #if DEBUG
    public let screenshotModeSession: String?
    #endif

    public init(stack: CoreDataStack) {
        self.stack = stack
        repositories = Repositories(stack: stack)
        #if DEBUG
        screenshotModeSession = nil
        #endif
    }

    #if DEBUG
    init(stack: CoreDataStack, screenshotModeSession: String) {
        self.stack = stack
        repositories = Repositories(stack: stack)
        self.screenshotModeSession = screenshotModeSession
    }
    #endif

    public static func inMemory(author: TransactionAuthor = .tests) -> PersistenceController {
        PersistenceController(stack: CoreDataStack(inMemoryAuthor: author))
    }

    public static func appGroupWithoutMirroring(author: TransactionAuthor) -> PersistenceController {
        PersistenceController(stack: CoreDataStack(appGroupAuthor: author, mirroring: .disabled))
    }

    public var viewContext: NSManagedObjectContext { stack.viewContext }
}
