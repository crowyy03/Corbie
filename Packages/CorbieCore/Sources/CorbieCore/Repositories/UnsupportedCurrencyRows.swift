import CoreData
import Foundation

struct UnsupportedCurrencyRows: Sendable {
    let entityName: String
    let currencyKey: String
    let spaceIdKeyPath: String

    func request(spaceId: UUID) -> NSFetchRequest<NSManagedObject> {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(
            format: "%K == %@ AND %K != nil AND NOT (%K IN %@)",
            spaceIdKeyPath,
            spaceId as NSUUID,
            currencyKey,
            currencyKey,
            SupportedCurrencies.codes
        )
        return request
    }
}

extension CoreDataAccess {
    func replaceUnsupportedCurrencies(in rows: [UnsupportedCurrencyRows], spaceId: UUID) async throws -> Int {
        let pending = try await read { context in
            try rows.reduce(0) { total, row in
                total + (try context.count(for: row.request(spaceId: spaceId)))
            }
        }
        guard pending > 0 else { return 0 }
        return try await write { context in
            var replaced = 0
            for row in rows {
                for object in try context.fetch(row.request(spaceId: spaceId)) {
                    object.setValue(SupportedCurrencies.defaultCode, forKey: row.currencyKey)
                    replaced += 1
                }
            }
            return replaced
        }
    }
}
