import CoreData
import Foundation

public struct CoreDataSpaceRepository: SpaceRepository {
    private let access: CoreDataAccess

    public init(stack: CoreDataStack) {
        access = CoreDataAccess(stack: stack)
    }

    public func create(displayCurrency: String, creatorMemberId: UUID?, now: Date) async throws -> SpaceDTO {
        try await access.write { context in
            let space = Space(context: context)
            if let store = access.stack.store(for: .privateStore) {
                context.assign(space, to: store)
            }
            space.createdAt = now
            space.displayCurrency = displayCurrency
            space.creatorMemberId = creatorMemberId
            space.subscriptionStatus = .none
            space.anchorTimeZone = TimeZone.current.identifier
            space.questionSeed = Int64(bitPattern: QuestionSelector.seed(forSpaceId: space.id ?? UUID()))
            return SpaceDTO(space)
        }
    }

    public func space(id: UUID) async throws -> SpaceDTO? {
        try await access.read { context in
            let space: Space? = try ManagedFetch.first(Space.entityName, id: id, in: context)
            return space.map(SpaceDTO.init)
        }
    }

    public func currentSpace(memberId: UUID?) async throws -> SpaceDTO? {
        let shared = access.stack.store(for: .sharedStore)
        let sharedIdentifier = shared === access.stack.store(for: .privateStore) ? nil : shared?.identifier
        return try await access.read { context in
            let spaces: [Space] = try ManagedFetch.all(
                Space.entityName,
                sort: [NSSortDescriptor(key: "createdAt", ascending: true)],
                in: context
            )
            let joined = spaces.filter { space in
                guard let sharedIdentifier else { return false }
                return space.objectID.persistentStore?.identifier == sharedIdentifier
            }
            if let memberId,
               let mine = joined.first(where: { space in space.members.contains { $0.id == memberId } }) {
                return SpaceDTO(mine)
            }
            if let first = joined.first { return SpaceDTO(first) }
            if let paired = spaces.first(where: { $0.members.count >= 2 }) { return SpaceDTO(paired) }
            if let memberId, let owned = spaces.first(where: { $0.creatorMemberId == memberId }) {
                return SpaceDTO(owned)
            }
            return spaces.first.map(SpaceDTO.init)
        }
    }

    public func update(_ space: SpaceDTO) async throws -> SpaceDTO {
        try await access.write { context in
            let entity: Space = try ManagedFetch.require(Space.entityName, id: space.id, in: context)
            entity.togetherSince = space.togetherSince
            entity.anchorTimeZone = space.anchorTimeZone ?? entity.anchorTimeZone
            entity.weddingDate = space.weddingDate
            entity.displayCurrency = space.displayCurrency
            entity.creatorMemberId = space.creatorMemberId
            entity.subscriptionStatus = space.subscriptionStatus
            entity.subscriptionExpiresAt = space.subscriptionExpiresAt
            entity.subscriptionPayerMemberId = space.subscriptionPayerMemberId
            return SpaceDTO(entity)
        }
    }

    public func setSubscription(
        spaceId: UUID,
        status: SubscriptionStatus,
        expiresAt: Date?,
        payerMemberId: UUID?
    ) async throws -> SpaceDTO {
        try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: spaceId, in: context)
            space.subscriptionStatus = status
            space.subscriptionExpiresAt = expiresAt
            space.subscriptionPayerMemberId = payerMemberId
            return SpaceDTO(space)
        }
    }

    public func delete(id: UUID) async throws {
        try await access.write { context in
            guard let space: Space = try ManagedFetch.first(Space.entityName, id: id, in: context) else { return }
            context.delete(space)
        }
    }
}
