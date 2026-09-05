import CoreData
import Foundation

public struct CoreDataWishRepository: WishRepository {
    private let access: CoreDataAccess

    public init(stack: CoreDataStack) {
        access = CoreDataAccess(stack: stack)
    }

    public func create(_ draft: WishDraft) async throws -> WishDTO {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false || draft.url?.isEmpty == false else {
            throw CorbieError.invalidInput("wish needs a title or a link")
        }
        return try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: draft.spaceId, in: context)
            let wish = Wish(context: context)
            wish.space = space
            wish.ownerMemberId = draft.ownerMemberId
            wish.addedByMemberId = draft.addedByMemberId
            wish.title = title
            wish.url = draft.url
            wish.imageURL = draft.imageURL
            wish.localImage = draft.localImage
            wish.price = draft.price.map(NSNumber.init(value:))
            wish.currency = draft.currency
            wish.priority = draft.priority
            wish.note = draft.note
            wish.source = draft.source
            wish.needsParse = draft.needsParse
            return WishDTO(wish)
        }
    }

    public func update(_ wish: WishDTO) async throws -> WishDTO {
        try await access.write { context in
            let entity: Wish = try ManagedFetch.require(Wish.entityName, id: wish.id, in: context)
            entity.ownerMemberId = wish.ownerMemberId
            entity.title = wish.title
            entity.url = wish.url
            entity.imageURL = wish.imageURL
            entity.localImage = wish.localImage
            entity.price = wish.price.map(NSNumber.init(value:))
            entity.currency = wish.currency
            entity.priority = wish.priority
            entity.note = wish.note
            entity.source = wish.source
            entity.isFulfilled = wish.isFulfilled
            entity.fulfilledAt = wish.fulfilledAt
            entity.needsParse = wish.needsParse
            return WishDTO(entity)
        }
    }

    public func fulfil(wishId: UUID, at date: Date) async throws -> WishDTO {
        try await access.write { context in
            let wish: Wish = try ManagedFetch.require(Wish.entityName, id: wishId, in: context)
            wish.isFulfilled = true
            wish.fulfilledAt = date
            return WishDTO(wish)
        }
    }

    public func wish(id: UUID) async throws -> WishDTO? {
        try await access.read { context in
            let wish: Wish? = try ManagedFetch.first(Wish.entityName, id: id, in: context)
            return wish.map(WishDTO.init)
        }
    }

    public func wishes(_ query: WishQuery) async throws -> [WishDTO] {
        try await access.read { context in
            var predicates = [ManagedFetch.spaceRelation(query.spaceId)]
            if case let .member(id) = query.owner {
                predicates.append(NSPredicate(format: "ownerMemberId == %@", id as NSUUID))
            }
            if let fulfilled = query.fulfilled {
                predicates.append(NSPredicate(format: "isFulfilled == %@", NSNumber(value: fulfilled)))
            }
            let wishes: [Wish] = try ManagedFetch.all(
                Wish.entityName,
                predicate: NSCompoundPredicate(andPredicateWithSubpredicates: predicates),
                sort: [NSSortDescriptor(key: "createdAt", ascending: false)],
                in: context
            )
            return wishes.map(WishDTO.init)
        }
    }

    public func pendingParse(spaceId: UUID) async throws -> [WishDTO] {
        try await access.read { context in
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                ManagedFetch.spaceRelation(spaceId),
                NSPredicate(format: "needsParse == YES")
            ])
            let wishes: [Wish] = try ManagedFetch.all(Wish.entityName, predicate: predicate, in: context)
            return wishes.map(WishDTO.init)
        }
    }

    public func delete(id: UUID) async throws {
        try await access.write { context in
            guard let wish: Wish = try ManagedFetch.first(Wish.entityName, id: id, in: context) else { return }
            context.delete(wish)
        }
    }
}
