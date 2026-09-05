import Foundation

public actor EntitlementService {
    public static let cacheKeyPrefix = "corbie.entitlement."

    private let client: APIClient
    private let spaces: any SpaceRepository
    private let store: (any SecretStore)?
    private let local: (any LocalEntitlementProviding)?
    private let now: @Sendable () -> Date

    private var lastState: EntitlementState = .readOnly

    public init(
        client: APIClient,
        spaces: any SpaceRepository,
        store: (any SecretStore)? = KeychainStore(),
        local: (any LocalEntitlementProviding)? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.spaces = spaces
        self.store = store
        self.local = local
        self.now = now
    }

    public var state: EntitlementState { lastState }

    public func refresh(spaceId: UUID) async -> EntitlementState {
        let space = try? await spaces.space(id: spaceId)
        let server = await serverEntitlement(spaceId: spaceId)
        let localEntitlement = await local?.currentEntitlement()
        let resolved = EntitlementResolver.resolve(
            EntitlementInputs(
                trialEndsAt: space?.trialEndsAt,
                server: server,
                local: localEntitlement,
                now: now()
            )
        )
        lastState = resolved
        await mirror(resolved, server: server, into: space)
        return resolved
    }

    public func cachedState(spaceId: UUID, trialEndsAt: Date?) -> EntitlementState {
        EntitlementResolver.resolve(
            EntitlementInputs(
                trialEndsAt: trialEndsAt,
                server: cachedEntitlement(spaceId: spaceId),
                local: nil,
                now: now()
            )
        )
    }

    public func extendTrialForSecondMember(space: SpaceDTO) async throws -> SpaceDTO {
        try await spaces.extendTrial(spaceId: space.id, days: SpaceDTO.trialDays, now: now())
    }

    public func cachedEntitlement(spaceId: UUID) -> ServerEntitlement? {
        guard let store,
              let data = try? store.data(for: EntitlementService.cacheKey(spaceId: spaceId))
        else { return nil }
        return try? CorbieJSON.decoder.decode(ServerEntitlement.self, from: data)
    }

    public func clearCache(spaceId: UUID) {
        try? store?.removeValue(for: EntitlementService.cacheKey(spaceId: spaceId))
    }

    public static func cacheKey(spaceId: UUID) -> String {
        cacheKeyPrefix + spaceId.uuidString.lowercased()
    }

    public static func mirroredStatus(_ state: EntitlementState, server: ServerEntitlement?) -> SubscriptionStatus {
        switch state {
        case .trial:
            return .trial
        case .active, .grace:
            return .active
        case .readOnly:
            guard let status = server?.status, status != EntitlementStatus.none else { return .readonly }
            return .expired
        }
    }

    private func serverEntitlement(spaceId: UUID) async -> ServerEntitlement? {
        do {
            let payload = try await client.entitlement(spaceId: spaceId)
            let entitlement = ServerEntitlement(payload: payload)
            cache(entitlement, spaceId: spaceId)
            return entitlement
        } catch {
            return cachedEntitlement(spaceId: spaceId)
        }
    }

    private func cache(_ entitlement: ServerEntitlement, spaceId: UUID) {
        guard let store, let data = try? CorbieJSON.encoder.encode(entitlement) else { return }
        try? store.setData(data, for: EntitlementService.cacheKey(spaceId: spaceId))
    }

    private func mirror(_ state: EntitlementState, server: ServerEntitlement?, into space: SpaceDTO?) async {
        guard let space else { return }
        let status = EntitlementService.mirroredStatus(state, server: server)
        let expiresAt = state.expiresAt ?? server?.expiresAt
        guard space.subscriptionStatus != status || space.subscriptionExpiresAt != expiresAt else { return }
        _ = try? await spaces.setSubscription(
            spaceId: space.id,
            status: status,
            expiresAt: expiresAt,
            payerMemberId: space.subscriptionPayerMemberId
        )
    }
}
