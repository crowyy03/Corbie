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
            context.assign(wish, toStoreOf: space)
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

    public func update(_ edited: WishDTO, from original: WishDTO) async throws -> WishDTO {
        let changes = try FieldChanges(edited, from: original)
        return try await access.write { context in
            let wish: Wish = try ManagedFetch.require(Wish.entityName, id: edited.id, in: context)
            changes.write(\.ownerMemberId) { wish.ownerMemberId = $0 }
            changes.write(\.title) { wish.title = $0 }
            changes.write(\.url) { wish.url = $0 }
            changes.write(\.imageURL) { wish.imageURL = $0 }
            changes.write(\.localImage) { wish.localImage = $0 }
            changes.write(\.price) { wish.price = $0.map(NSNumber.init(value:)) }
            changes.write(\.currency) { wish.currency = $0 }
            changes.write(\.priority) { wish.priority = $0 }
            changes.write(\.note) { wish.note = $0 }
            changes.write(\.source) { wish.source = $0 }
            changes.write(\.needsParse) { wish.needsParse = $0 }
            return WishDTO(wish)
        }
    }

    public func fillEmptyFields(wishId: UUID, parsedFrom link: String, with parsed: ParsedLink) async throws -> WishDTO {
        try await access.write { context in
            let wish: Wish = try ManagedFetch.require(Wish.entityName, id: wishId, in: context)
            guard wish.needsParse, wish.url == link, parsed.isEmpty == false else { return WishDTO(wish) }
            if (wish.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let title = parsed.title {
                wish.title = title
            }
            if wish.price == nil, let price = parsed.price {
                wish.price = NSNumber(value: price)
                wish.currency = Money.currencyCode(parsed.currency) ?? wish.currency
            }
            if (wish.imageURL ?? "").isEmpty, let imageURL = parsed.imageURL {
                wish.imageURL = imageURL.absoluteString
            }
            if wish.localImage == nil, let imageData = parsed.imageData {
                wish.localImage = imageData
            }
            if wish.source == .manual {
                wish.source = parsed.source
            }
            wish.needsParse = false
            return WishDTO(wish)
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
