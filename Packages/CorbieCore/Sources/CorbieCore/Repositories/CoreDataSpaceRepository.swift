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

    public func update(_ edited: SpaceDTO, from original: SpaceDTO) async throws -> SpaceDTO {
        let changes = try FieldChanges(edited, from: original)
        return try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: edited.id, in: context)
            changes.write(\.togetherSince) { space.togetherSince = $0 }
            changes.write(\.weddingDate) { space.weddingDate = $0 }
            changes.write(\.displayCurrency) { space.displayCurrency = $0 }
            return SpaceDTO(space)
        }
    }

    public func setTogetherSince(spaceId: UUID, _ date: Date?) async throws -> SpaceDTO {
        try await writeSpace(spaceId) { space in
            guard space.togetherSince != date else { return }
            space.togetherSince = date
        }
    }

    public func setTogetherSinceIfUnset(spaceId: UUID, _ date: Date) async throws -> SpaceDTO {
        try await writeSpace(spaceId) { space in
            guard space.togetherSince == nil else { return }
            space.togetherSince = date
        }
    }

    public func setWeddingDate(spaceId: UUID, _ date: Date?) async throws -> SpaceDTO {
        try await writeSpace(spaceId) { space in
            guard space.weddingDate != date else { return }
            space.weddingDate = date
        }
    }

    public func setDisplayCurrency(spaceId: UUID, _ code: String) async throws -> SpaceDTO {
        try await writeSpace(spaceId) { space in
            guard space.displayCurrency != code else { return }
            space.displayCurrency = code
        }
    }

    public func replaceUnsupportedDisplayCurrency(spaceId: UUID) async throws -> Int {
        try await access.replaceUnsupportedCurrencies(
            in: [UnsupportedCurrencyRows(entityName: Space.entityName, currencyKey: "displayCurrency", spaceIdKeyPath: "id")],
            spaceId: spaceId
        )
    }

    public func setCreatorIfUnset(spaceId: UUID, memberId: UUID) async throws -> SpaceDTO {
        try await writeSpace(spaceId) { space in
            guard space.creatorMemberId == nil else { return }
            space.creatorMemberId = memberId
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

    private func writeSpace(_ spaceId: UUID, _ change: @escaping @Sendable (Space) -> Void) async throws -> SpaceDTO {
        try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: spaceId, in: context)
            change(space)
            return SpaceDTO(space)
        }
    }
}
