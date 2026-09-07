import Foundation

public actor EntitlementService {
    public static let cacheKeyPrefix = "corbie.entitlement."

    private let client: APIClient
    private let spaces: any SpaceRepository
    private let store: (any SecretStore)?
    private let local: (any LocalEntitlementProviding)?
    private let notifications: NotificationScheduler?
    private let now: @Sendable () -> Date

    private var lastState: EntitlementState = .readOnly

    public init(
        client: APIClient,
        spaces: any SpaceRepository,
        store: (any SecretStore)? = KeychainStore(),
        local: (any LocalEntitlementProviding)? = nil,
        notifications: NotificationScheduler? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.spaces = spaces
        self.store = store
        self.local = local
        self.notifications = notifications
        self.now = now
    }

    public var state: EntitlementState { lastState }

    public func refresh(spaceId: UUID) async -> EntitlementState {
        let space = try? await spaces.space(id: spaceId)
        let server = await serverEntitlement(spaceId: spaceId)
        let localEntitlement = await local?.currentEntitlement()
        let resolved = EntitlementResolver.resolve(
            EntitlementInputs(
                local: localEntitlement,
                server: server,
                space: space.map(MirroredEntitlement.init(space:)),
                now: now()
            )
        )
        await mirror(resolved, server: server, into: space)
        let effective = EntitlementService.forcedState(now: now()) ?? resolved
        lastState = effective
        await scheduleTrialEnding(effective)
        return effective
    }

    public func cachedState(space: SpaceDTO) -> EntitlementState {
        if let forced = EntitlementService.forcedState(now: now()) { return forced }
        return EntitlementResolver.resolve(
            EntitlementInputs(
                server: cachedEntitlement(spaceId: space.id),
                space: MirroredEntitlement(space: space),
                now: now()
            )
        )
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
        case .premium, .grace:
            return .active
        case .readOnly:
            guard let status = server?.status, status != EntitlementStatus.none else { return .readonly }
            return .expired
        }
    }

    private static func forcedState(now: Date) -> EntitlementState? {
        #if DEBUG
        return DebugEntitlementOverride.stored()?.state(now: now)
        #else
        return nil
        #endif
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

    private func scheduleTrialEnding(_ state: EntitlementState) async {
        guard let notifications else { return }
        guard let endsAt = state.trialEndsAt else {
            await notifications.cancelTrialEnding()
            return
        }
        _ = try? await notifications.scheduleTrialEnding(endsAt: endsAt, now: now())
    }
}
