import Foundation

public protocol SpaceRepository: Sendable {
    func create(displayCurrency: String, creatorMemberId: UUID?, now: Date) async throws -> SpaceDTO
    func space(id: UUID) async throws -> SpaceDTO?
    func firstSpace() async throws -> SpaceDTO?
    func update(_ space: SpaceDTO) async throws -> SpaceDTO
    func extendTrial(spaceId: UUID, days: Int, now: Date) async throws -> SpaceDTO
    func setSubscription(
        spaceId: UUID,
        status: SubscriptionStatus,
        expiresAt: Date?,
        payerMemberId: UUID?
    ) async throws -> SpaceDTO
    func delete(id: UUID) async throws
}

extension SpaceRepository {
    public func create(displayCurrency: String = "USD", creatorMemberId: UUID? = nil) async throws -> SpaceDTO {
        try await create(displayCurrency: displayCurrency, creatorMemberId: creatorMemberId, now: Date())
    }

    public func extendTrial(spaceId: UUID) async throws -> SpaceDTO {
        try await extendTrial(spaceId: spaceId, days: SpaceDTO.trialDays, now: Date())
    }
}
