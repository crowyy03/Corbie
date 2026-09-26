import Foundation

public actor EntitlementService {
    public static let cacheKeyPrefix = "corbie.entitlement."
    public static let syncedKeyPrefix = "corbie.entitlement.synced."

    private let client: APIClient
    private let spaces: any SpaceRepository
    private let monetization: any MonetizationSource
    private let store: (any SecretStore)?
    private let local: (any LocalEntitlementProviding)?
    private let appTransaction: (any AppTransactionProviding)?
    private let device: DeviceEntitlementStore?
    private let notifications: NotificationScheduler?
    private let now: @Sendable () -> Date

    private var lastState: EntitlementState = .readOnly

    public init(
        client: APIClient,
        spaces: any SpaceRepository,
        monetization: any MonetizationSource,
        store: (any SecretStore)? = KeychainStore(),
        local: (any LocalEntitlementProviding)? = nil,
        appTransaction: (any AppTransactionProviding)? = nil,
        device: DeviceEntitlementStore? = nil,
        notifications: NotificationScheduler? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.spaces = spaces
        self.monetization = monetization
        self.store = store
        self.local = local
        self.appTransaction = appTransaction
        self.device = device
        self.notifications = notifications
        self.now = now
    }

    public var state: EntitlementState { lastState }

    public func refresh(spaceId: UUID) async -> EntitlementState {
        await refreshResolution(spaceId: spaceId).state
    }

    public func refreshResolution(spaceId: UUID) async -> EntitlementResolution {
        guard await monetization.refresh() else { return await settleWithoutMonetization() }
        let proof = await appTransaction?.appTransactionProof()
        let environment = StoreEnvironmentRule.readable(proof)
        let moment = now()
        let space = try? await spaces.space(id: spaceId)
        let subscriptions = LocalSubscriptions(await local?.subscriptions() ?? [])
        var server = await serverEntitlement(spaceId: spaceId, proof: proof)
        if let moving = subscriptions.activeOutside(spaceId, at: moment),
           hasSynced(moving, spaceId: spaceId) == false,
           let moved = await sync(moving.signedTransaction, spaceId: spaceId, proof: proof) {
            markSynced(moving, spaceId: spaceId)
            server = moved
        }
        let inputs = EntitlementInputs(
            environment: environment,
            local: subscriptions.entitlement(for: spaceId),
            server: server,
            space: space.map(MirroredEntitlement.init(space:)),
            now: moment
        )
        let resolved = EntitlementResolver.resolution(inputs)
        if StoreEnvironmentRule.mayWriteMirror(proof) {
            let productionOnly = inputs.withLocal(subscriptions.production.entitlement(for: spaceId))
            await mirror(EntitlementResolver.resolution(productionOnly), inputs: productionOnly, into: space)
        }
        let effective = EntitlementService.forced(resolved, now: moment)
        if device?.record(effective.state, spaceId: spaceId, environment: environment, now: moment) == true {
            WidgetReloadRequest.post()
        }
        lastState = effective.state
        await scheduleTrialEnding(effective.state)
        return effective
    }

    public func refreshWithoutSpace() async -> EntitlementState {
        guard await monetization.refresh() else { return await settleWithoutMonetization().state }
        lastState = .readOnly
        return lastState
    }

    public nonisolated func stateWithoutSpace() -> EntitlementState {
        monetization.isEnabled ? .readOnly : .monetizationOff
    }

    public func cachedState(space: SpaceDTO) async -> EntitlementState {
        await cachedResolution(space: space).state
    }

    public func cachedResolution(space: SpaceDTO) async -> EntitlementResolution {
        guard monetization.isEnabled else { return EntitlementResolution(state: .monetizationOff) }
        let proof = await appTransaction?.appTransactionProof()
        let environment = StoreEnvironmentRule.readable(proof)
        let moment = now()
        let resolved = EntitlementResolver.resolution(
            EntitlementInputs(
                environment: environment,
                server: cachedEntitlement(spaceId: space.id),
                space: MirroredEntitlement(space: space),
                now: moment
            )
        )
        if resolved.state.isReadOnly,
           let snapshot = device?.snapshot(spaceId: space.id, at: moment),
           snapshot.environment == environment {
            return EntitlementService.forced(
                EntitlementResolution(state: .premium(source: .storeKit, expiresAt: snapshot.premiumUntil)),
                now: moment
            )
        }
        return EntitlementService.forced(resolved, now: moment)
    }

    public func syncPurchase(signedTransaction: String, spaceId: UUID) async {
        let proof = await appTransaction?.appTransactionProof()
        _ = await sync(signedTransaction, spaceId: spaceId, proof: proof)
    }

    public func reconcileAfterRestore(spaceId: UUID?) async -> RestoreOutcome {
        let proof = await appTransaction?.appTransactionProof()
        let moment = now()
        let subscriptions = LocalSubscriptions(await local?.subscriptions() ?? [])
        if let spaceId, let reconciling = subscriptions.toReconcile(for: spaceId, at: moment),
           await sync(reconciling.signedTransaction, spaceId: spaceId, proof: proof) != nil,
           reconciling.appAccountToken != spaceId {
            markSynced(reconciling, spaceId: spaceId)
        }
        return subscriptions.active(at: moment).isEmpty ? .nothingToRestore : .restored
    }

    public func cachedEntitlement(spaceId: UUID) -> ServerEntitlement? {
        guard let store,
              let data = try? store.data(for: EntitlementService.cacheKey(spaceId: spaceId))
        else { return nil }
        return try? CorbieJSON.decoder.decode(ServerEntitlement.self, from: data)
    }

    public func clearCache(spaceId: UUID) {
        try? store?.removeValue(for: EntitlementService.cacheKey(spaceId: spaceId))
        try? store?.removeValue(for: EntitlementService.syncedKey(spaceId: spaceId))
    }

    public static func cacheKey(spaceId: UUID) -> String {
        cacheKeyPrefix + spaceId.uuidString.lowercased()
    }

    public static func syncedKey(spaceId: UUID) -> String {
        syncedKeyPrefix + spaceId.uuidString.lowercased()
    }

    public static func mirroredStatus(_ resolution: EntitlementResolution) -> SubscriptionStatus {
        switch resolution.state {
        case .trial:
            return .trial
        case .premium, .grace:
            return .active
        case .readOnly:
            switch resolution.readOnlyCause ?? .neverSubscribed {
            case .neverSubscribed: return .readonly
            case .subscriptionEnded: return .expired
            case .trialEnded: return .trial
            }
        }
    }

    private static func forced(_ resolved: EntitlementResolution, now: Date) -> EntitlementResolution {
        #if DEBUG
        guard let override = DebugEntitlementOverride.stored(), let forced = override.state(now: now) else { return resolved }
        return EntitlementResolution(state: forced, readOnlyCause: override.readOnlyCause ?? resolved.readOnlyCause)
        #else
        return resolved
        #endif
    }

    private func serverEntitlement(spaceId: UUID, proof: AppTransactionProof?) async -> ServerEntitlement? {
        do {
            let payload = try await client.entitlement(spaceId: spaceId, appTransaction: proof?.signedAppTransaction)
            let entitlement = ServerEntitlement(payload: payload)
            cache(entitlement, spaceId: spaceId, proof: proof)
            return entitlement
        } catch {
            return cachedEntitlement(spaceId: spaceId)
        }
    }

    private func sync(_ signedTransaction: String, spaceId: UUID, proof: AppTransactionProof?) async -> ServerEntitlement? {
        guard let payload = try? await client.syncEntitlement(
            spaceId: spaceId,
            signedTransaction: signedTransaction,
            appTransaction: proof?.signedAppTransaction
        ) else { return nil }
        let entitlement = ServerEntitlement(payload: payload)
        cache(entitlement, spaceId: spaceId, proof: proof)
        return entitlement
    }

    private func cache(_ entitlement: ServerEntitlement, spaceId: UUID, proof: AppTransactionProof?) {
        guard entitlement.environment == StoreEnvironmentRule.readable(proof),
              let store,
              let data = try? CorbieJSON.encoder.encode(entitlement)
        else { return }
        try? store.setData(data, for: EntitlementService.cacheKey(spaceId: spaceId))
    }

    private func hasSynced(_ subscription: StoreSubscription, spaceId: UUID) -> Bool {
        let stored = try? store?.string(for: EntitlementService.syncedKey(spaceId: spaceId))
        return stored == EntitlementService.syncedMarker(subscription)
    }

    private func markSynced(_ subscription: StoreSubscription, spaceId: UUID) {
        try? store?.setString(EntitlementService.syncedMarker(subscription), for: EntitlementService.syncedKey(spaceId: spaceId))
    }

    private static func syncedMarker(_ subscription: StoreSubscription) -> String {
        "\(subscription.environment.rawValue):\(subscription.transactionId)"
    }

    private func mirror(_ resolution: EntitlementResolution, inputs: EntitlementInputs, into space: SpaceDTO?) async {
        guard let space else { return }
        let status = EntitlementService.mirroredStatus(resolution)
        let expiresAt = resolution.state.expiresAt
            ?? inputs.local?.expiresAt
            ?? inputs.readableServer?.expiresAt
            ?? inputs.readableMirror?.expiresAt
        let keepsTheRunningTrial = status == .active
            && space.subscriptionStatus == .trial
            && space.subscriptionExpiresAt == expiresAt
        guard keepsTheRunningTrial == false,
              space.subscriptionStatus != status || space.subscriptionExpiresAt != expiresAt
        else { return }
        _ = try? await spaces.setSubscription(
            spaceId: space.id,
            status: status,
            expiresAt: expiresAt,
            payerMemberId: space.subscriptionPayerMemberId
        )
    }

    private func settleWithoutMonetization() async -> EntitlementResolution {
        lastState = .monetizationOff
        await notifications?.cancelTrialEnding()
        return EntitlementResolution(state: .monetizationOff)
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
