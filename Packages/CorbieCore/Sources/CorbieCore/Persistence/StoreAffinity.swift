import CoreData
import Foundation

extension NSManagedObjectContext {
    func assign(_ object: NSManagedObject, toStoreOf parent: NSManagedObject) {
        guard let store = parent.objectID.persistentStore else { return }
        assign(object, to: store)
    }
}
