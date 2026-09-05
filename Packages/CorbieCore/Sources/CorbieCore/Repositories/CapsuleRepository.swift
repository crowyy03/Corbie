import Foundation

public struct CapsuleDraft: Sendable, Equatable {
    public var spaceId: UUID
    public var authorMemberId: UUID?
    public var recipientMemberId: UUID?
    public var title: String
    public var body: String
    public var opensAt: Date

    public init(
        spaceId: UUID,
        authorMemberId: UUID? = nil,
        recipientMemberId: UUID? = nil,
        title: String,
        body: String,
        opensAt: Date
    ) {
        self.spaceId = spaceId
        self.authorMemberId = authorMemberId
        self.recipientMemberId = recipientMemberId
        self.title = title
        self.body = body
        self.opensAt = opensAt
    }
}

public protocol CapsuleRepository: Sendable {
    func create(_ draft: CapsuleDraft, now: Date) async throws -> CapsuleDTO
    func update(_ capsule: CapsuleDTO, now: Date) async throws -> CapsuleDTO
    func markOpened(capsuleId: UUID, memberId: UUID, at date: Date) async throws -> CapsuleDTO
    func capsule(id: UUID) async throws -> CapsuleDTO?
    func capsules(spaceId: UUID) async throws -> [CapsuleDTO]
    func delete(id: UUID) async throws
}

extension CapsuleRepository {
    public func create(_ draft: CapsuleDraft) async throws -> CapsuleDTO {
        try await create(draft, now: Date())
    }

    public func update(_ capsule: CapsuleDTO) async throws -> CapsuleDTO {
        try await update(capsule, now: Date())
    }

    public func markOpened(capsuleId: UUID, memberId: UUID) async throws -> CapsuleDTO {
        try await markOpened(capsuleId: capsuleId, memberId: memberId, at: Date())
    }
}
