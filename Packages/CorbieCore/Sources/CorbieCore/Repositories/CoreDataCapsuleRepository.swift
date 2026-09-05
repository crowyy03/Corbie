import CoreData
import Foundation

public struct CoreDataCapsuleRepository: CapsuleRepository {
    private let access: CoreDataAccess

    public init(stack: CoreDataStack) {
        access = CoreDataAccess(stack: stack)
    }

    public func create(_ draft: CapsuleDraft, now: Date) async throws -> CapsuleDTO {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            throw CorbieError.invalidInput("capsule title is empty")
        }
        guard draft.body.count <= CapsuleItem.maxBodyLength else {
            throw CorbieError.invalidInput("capsule body is longer than \(CapsuleItem.maxBodyLength)")
        }
        guard draft.opensAt > now else {
            throw CorbieError.invalidInput("capsule opens in the past")
        }
        return try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: draft.spaceId, in: context)
            let capsule = CapsuleItem(context: context)
            context.assign(capsule, toStoreOf: space)
            capsule.space = space
            capsule.authorMemberId = draft.authorMemberId
            capsule.recipientMemberId = draft.recipientMemberId
            capsule.title = title
            capsule.body = draft.body
            capsule.opensAt = draft.opensAt
            capsule.openedByMemberIds = []
            return CapsuleDTO(capsule)
        }
    }

    public func update(_ capsule: CapsuleDTO, now: Date) async throws -> CapsuleDTO {
        guard capsule.body.count <= CapsuleItem.maxBodyLength else {
            throw CorbieError.invalidInput("capsule body is longer than \(CapsuleItem.maxBodyLength)")
        }
        return try await access.write { context in
            let entity: CapsuleItem = try ManagedFetch.require(CapsuleItem.entityName, id: capsule.id, in: context)
            guard entity.openedAt == nil, (entity.opensAt ?? now) > now else {
                throw CorbieError.invalidInput("capsule is already open")
            }
            entity.title = capsule.title
            entity.body = capsule.body
            entity.opensAt = capsule.opensAt
            entity.recipientMemberId = capsule.recipientMemberId
            return CapsuleDTO(entity)
        }
    }

    public func markOpened(capsuleId: UUID, memberId: UUID, at date: Date) async throws -> CapsuleDTO {
        try await access.write { context in
            let capsule: CapsuleItem = try ManagedFetch.require(CapsuleItem.entityName, id: capsuleId, in: context)
            guard let opensAt = capsule.opensAt, opensAt <= date else {
                throw CorbieError.invalidInput("capsule is still sealed")
            }
            if capsule.openedAt == nil {
                capsule.openedAt = date
            }
            var opened = capsule.openedByMemberIds
            if opened.contains(memberId) == false {
                opened.append(memberId)
                capsule.openedByMemberIds = opened
            }
            return CapsuleDTO(capsule)
        }
    }

    public func capsule(id: UUID) async throws -> CapsuleDTO? {
        try await access.read { context in
            let capsule: CapsuleItem? = try ManagedFetch.first(CapsuleItem.entityName, id: id, in: context)
            return capsule.map(CapsuleDTO.init)
        }
    }

    public func capsules(spaceId: UUID) async throws -> [CapsuleDTO] {
        try await access.read { context in
            let capsules: [CapsuleItem] = try ManagedFetch.all(
                CapsuleItem.entityName,
                predicate: ManagedFetch.spaceRelation(spaceId),
                sort: [NSSortDescriptor(key: "opensAt", ascending: true)],
                in: context
            )
            return capsules.map(CapsuleDTO.init)
        }
    }

    public func delete(id: UUID) async throws {
        try await access.write { context in
            let capsule: CapsuleItem? = try ManagedFetch.first(CapsuleItem.entityName, id: id, in: context)
            guard let capsule else { return }
            context.delete(capsule)
        }
    }
}
