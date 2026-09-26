import CorbieCore
import CoreData
import EventKit
import Observation
import os
import SwiftUI
import UIKit

@MainActor
@Observable
final class AppEnvironment {
    enum Session: Equatable {
        case loading
        case signedOut
        case signedIn(SessionContext)
    }

    struct SessionContext: Equatable {
        var space: SpaceDTO
        var member: MemberDTO
        var partner: MemberDTO?
    }

    nonisolated static let sessionTokenKey = "server.session.token"
    nonisolated static let appleIdentityTokenKey = "apple.identity.token"
    nonisolated static let appleRefreshTokenKey = "apple.refresh.token"
    #if DEBUG
    nonisolated static let analyticsDelivery = AnalyticsDelivery.discarded
    #else
    nonisolated static let analyticsDelivery = AnalyticsDelivery.server
    #endif
    nonisolated static let partnerCheckIntervalOnRemoteChange: TimeInterval = 60
    nonisolated static let partnerCheckIntervalOnForeground: TimeInterval = 5

    private nonisolated static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "sharing")

    @ObservationIgnored let persistence: PersistenceController
    @ObservationIgnored let repositories: Repositories
    @ObservationIgnored let identity: MemberIdentity
    @ObservationIgnored let anonymousIdentity: AnonymousIdentity
    @ObservationIgnored let secrets: any SecretStore
    @ObservationIgnored let sharing: CloudKitSharing
    @ObservationIgnored let apiClient: APIClient
    @ObservationIgnored let analytics: Analytics
    @ObservationIgnored let entitlements: EntitlementService
    @ObservationIgnored let store: StoreService
    @ObservationIgnored let fx: FXService
    @ObservationIgnored let linkParser: LinkParser
    @ObservationIgnored let notifications: NotificationScheduler
    @ObservationIgnored let remoteChanges: RemoteChangeNotifier
    @ObservationIgnored let reviewPrompt: ReviewPromptTracker
    @ObservationIgnored let sessionService: SessionService
    @ObservationIgnored let defaults: UserDefaults
    @ObservationIgnored private let intents: IntentPersistence
    @ObservationIgnored private let storageProbe: @MainActor () -> StorageHealth?
    @ObservationIgnored private let deviceCalendar: (any DeviceCalendarSource)?

    @ObservationIgnored private(set) var busyPublisher: BusyPublisher?
    @ObservationIgnored private var corbieEventBusyPublisher: CorbieEventBusyPublisher?
    @ObservationIgnored private var busySourceObservers: [any NSObjectProtocol] = []

    let premiumGate: PremiumGate
    let usBadge: UsBadgeProvider
    let toasts: ToastCenter
    let theme: ThemeProvider

    private(set) var session: Session = .loading

    @ObservationIgnored private var hasResyncedNotifications = false
    @ObservationIgnored private var processStart: Task<Void, Never>?
    @ObservationIgnored private var processStartedInBackground = false
    @ObservationIgnored private var partnerCheck: Task<PartnerCheck, Never>?
    @ObservationIgnored private var spaceCheck: Task<Void, Never>?
    @ObservationIgnored private var isCheckingPartnerOnServer = false
    @ObservationIgnored private var partnerCheckPauses = 0
    @ObservationIgnored private(set) var storage: StorageHealth?
    @ObservationIgnored private var partnerCheckedOnServerAt: Date?
    #if DEBUG
    @ObservationIgnored var isParkedForScreenshotMode = false
    #endif

    init(
        persistence: PersistenceController = .shared,
        secrets: any SecretStore = KeychainStore(),
        anonymousIdentity: AnonymousIdentity = .shared,
        notificationClient: any NotificationCenterClient = SystemNotificationCenterClient(),
        store: StoreService = .shared,
        localEntitlements: (any LocalEntitlementProviding)? = nil,
        transport: (any HTTPTransport)? = nil,
        defaults: UserDefaults = .corbieShared,
        analyticsDelivery: AnalyticsDelivery = AppEnvironment.analyticsDelivery,
        analyticsStorage: any AnalyticsStorage = FileAnalyticsStorage(),
        theme: ThemeProvider? = nil,
        intents: IntentPersistence = .shared,
        storageProbe: @escaping @MainActor () -> StorageHealth? = { StorageProbe.run(process: "app") },
        deviceCalendar: (any DeviceCalendarSource)? = nil
    ) {
        self.persistence = persistence
        repositories = persistence.repositories
        self.secrets = secrets
        self.defaults = defaults
        self.intents = intents
        self.storageProbe = storageProbe
        self.deviceCalendar = deviceCalendar
        reviewPrompt = ReviewPromptTracker(defaults: defaults)
        identity = MemberIdentity(store: secrets)
        self.anonymousIdentity = anonymousIdentity
        sharing = CloudKitSharing(stack: persistence.stack)
        let tokenProvider: AppleTokenProvider = { [secrets] in
            if let token = try secrets.string(for: AppEnvironment.sessionTokenKey) { return token }
            return try secrets.string(for: AppEnvironment.appleIdentityTokenKey)
        }
        let serverTransport = transport ?? URLSessionTransport()
        let client = APIClient(
            transport: serverTransport,
            identity: anonymousIdentity,
            appleToken: tokenProvider
        )
        apiClient = client
        sessionService = SessionService(configuration: client.configuration)
        analytics = Analytics(
            client: client,
            storage: analyticsStorage,
            identity: anonymousIdentity,
            delivery: analyticsDelivery
        )
        self.store = store
        let scheduler = NotificationScheduler(client: notificationClient)
        notifications = scheduler
        let entitlementService = EntitlementService(
            client: client,
            spaces: persistence.repositories.spaces,
            monetization: ServerMonetizationFlag(client: client),
            store: secrets,
            local: localEntitlements ?? store,
            appTransaction: store,
            device: DeviceEntitlementStore(defaults: defaults),
            notifications: scheduler
        )
        entitlements = entitlementService
        premiumGate = PremiumGate(
            state: MonetizationFlagStore().isEnabled ? .readOnly : .monetizationOff,
            analytics: analytics,
            entitlements: entitlementService
        )
        usBadge = UsBadgeProvider(repositories: repositories)
        fx = FXService(client: client, defaults: defaults)
        linkParser = LinkParser(client: client, imageTransport: serverTransport)
        remoteChanges = RemoteChangeNotifier(
            stack: persistence.stack,
            scheduler: scheduler,
            reminders: PartnerProgressReminders(
                chores: persistence.repositories.chores,
                questions: persistence.repositories.questions,
                scheduler: scheduler,
                defaults: defaults
            ),
            defaults: defaults
        )
        toasts = ToastCenter()
        self.theme = theme ?? ThemeProvider()
    }

    var space: SpaceDTO? {
        if case let .signedIn(context) = session { return context.space }
        return nil
    }

    var currentMember: MemberDTO? {
        if case let .signedIn(context) = session { return context.member }
        return nil
    }

    var partner: MemberDTO? {
        if case let .signedIn(context) = session { return context.partner }
        return nil
    }

    var isSignedIn: Bool {
        if case .signedIn = session { return true }
        return false
    }

    var isPaired: Bool { partner != nil }

    func startProcess() {
        guard processStart == nil else { return }
        apiClient.configuration.announce(process: "app")
        storage = storageProbe()
        processStartedInBackground = UIApplication.shared.applicationState == .background
        intents.use(controller: persistence, identity: identity)
        WidgetReloader.shared.start()
        processStart = Task { await prepareProcess() }
    }

    func processReady() async {
        startProcess()
        await processStart?.value
    }

    func bootstrap() async {
        reportStorageFailure()
        usBadge.observeReloads()
        await analytics.start()
        reviewPrompt.recordLaunch()
        await processReady()
        if case let .signedIn(context) = session {
            await runSessionUpkeep(context)
        } else if processStartedInBackground {
            await reloadSession()
        }
    }

    func remotePushSync(scope: StoreScope?) -> RemotePushSync {
        RemotePushSync(stack: persistence.stack, notifier: remoteChanges, scope: scope)
    }

    func reloadSession() async {
        guard let context = await loadSession() else { return }
        await runSessionUpkeep(context)
    }

    private func prepareProcess() async {
        do {
            try persistence.stack.initializeCloudKitSchemaIfRequested()
        } catch {
            report(error)
        }
        await notifications.registerCategories()
        await loadSession()
        await remoteChanges.start()
    }

    @discardableResult
    private func loadSession() async -> SessionContext? {
        guard let appleUserID = identity.currentAppleUserID else {
            session = .signedOut
            premiumGate.update(entitlements.stateWithoutSpace())
            return nil
        }
        do {
            guard let member = try await repositories.members.member(appleUserId: appleUserID),
                  let space = try await repositories.spaces.currentSpace(memberId: member.id)
            else {
                forgetAppleUserWithoutMember()
                session = .signedOut
                premiumGate.update(entitlements.stateWithoutSpace())
                return nil
            }
            let partner = try await repositories.members.partner(of: member.id, spaceId: space.id)
            let context = SessionContext(space: space, member: member, partner: partner)
            session = .signedIn(context)
            startBusyPublishing(spaceId: space.id)
            await updateNotificationAudience()
            await resyncNotificationBacklog()
            premiumGate.apply(await entitlements.cachedResolution(space: space))
            return context
        } catch {
            session = .signedOut
            report(error)
            return nil
        }
    }

    private func runSessionUpkeep(_ context: SessionContext) async {
        try? await repositories.members.touchLastSeen(memberId: context.member.id)
        Task { await premiumGate.refresh(spaceId: context.space.id) }
        Task { await publishBusyTimes() }
        Task { await reconcilePartnerMembership() }
        Task { try? await UnsupportedCurrencyRepair(repositories: repositories).run(spaceId: context.space.id) }
        Task { await consolidateQuestionDuplicates() }
    }

    func consolidateQuestionDuplicates() async {
        guard let spaceId = space?.id else { return }
        _ = try? await repositories.questions.consolidateDuplicates(spaceId: spaceId)
    }

    private var arePartnerChecksPaused: Bool { partnerCheckPauses > 0 }

    func withPartnerChecksPaused(_ body: () async -> Void) async {
        partnerCheckPauses += 1
        defer { partnerCheckPauses -= 1 }
        await body()
    }

    func refreshSessionFromStore() async {
        guard await reloadSessionIfPartnerChanged() == .unchanged else { return }
        let previous = spaceCheck
        let check = Task {
            _ = await previous?.value
            await self.applyStoredSpaceIfItDiffers()
        }
        spaceCheck = check
        await check.value
    }

    private func applyStoredSpaceIfItDiffers() async {
        guard arePartnerChecksPaused == false, case let .signedIn(context) = session else { return }
        let stored: SpaceDTO?
        do {
            stored = try await repositories.spaces.space(id: context.space.id)
        } catch {
            AppEnvironment.log.error("space lookup failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard let stored,
              arePartnerChecksPaused == false,
              case let .signedIn(current) = session,
              current.space.id == stored.id,
              current.space != stored
        else { return }
        apply(space: stored)
    }

    @discardableResult
    func reloadSessionIfPartnerChanged() async -> PartnerCheck {
        let previous = partnerCheck
        let check = Task {
            _ = await previous?.value
            return await self.reloadSessionIfStoredPartnerDiffers()
        }
        partnerCheck = check
        return await check.value
    }

    private func reloadSessionIfStoredPartnerDiffers() async -> PartnerCheck {
        guard arePartnerChecksPaused == false, case let .signedIn(context) = session else { return .unchanged }
        let stored: MemberDTO?
        do {
            stored = try await repositories.members.partner(of: context.member.id, spaceId: context.space.id)
        } catch {
            AppEnvironment.log.error("partner lookup failed: \(error.localizedDescription, privacy: .public)")
            return .unreadable
        }
        guard arePartnerChecksPaused == false,
              case let .signedIn(current) = session,
              current.member.id == context.member.id,
              current.space.id == context.space.id,
              PartnerChangeRule.needsReload(stored: stored, session: current.partner)
        else { return .unchanged }
        await reloadSession()
        return .reloaded
    }

    func reconcilePartnerMembership(serverCheckInterval: TimeInterval = 0) async {
        guard arePartnerChecksPaused == false,
              case let .signedIn(context) = session,
              context.partner != nil
        else { return }
        guard await reloadSessionIfPartnerChanged() == .unchanged, arePartnerChecksPaused == false else { return }
        guard isCheckingPartnerOnServer == false, isPartnerServerCheckDue(interval: serverCheckInterval) else { return }
        isCheckingPartnerOnServer = true
        partnerCheckedOnServerAt = Date()
        defer { isCheckingPartnerOnServer = false }
        do {
            let removed = try await sharing.removeDepartedMembers(
                space: context.space.id,
                ownerMemberId: context.member.id
            )
            guard removed.isEmpty == false, arePartnerChecksPaused == false else { return }
            await reloadSession()
        } catch {
            AppEnvironment.log.error("partner check skipped: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func isPartnerServerCheckDue(interval: TimeInterval) -> Bool {
        guard let partnerCheckedOnServerAt else { return true }
        return Date().timeIntervalSince(partnerCheckedOnServerAt) >= interval
    }

    func publishBusyTimes(force: Bool = false) async {
        guard mayPublishBusyTimes, case let .signedIn(context) = session else { return }
        do {
            try await repositories.busyIntervals.purge(before: Date())
        } catch {
            report(error)
        }
        if let corbieEventBusyPublisher {
            do {
                try await corbieEventBusyPublisher.publish(
                    spaceId: context.space.id,
                    memberId: context.member.id,
                    sharesBusyTimes: context.member.sharesBusyTimes,
                    force: force
                )
            } catch {
                report(error)
            }
        }
        guard let busyPublisher else { return }
        do {
            _ = try await busyPublisher.publish(
                memberId: context.member.id,
                sharesBusyTimes: context.member.sharesBusyTimes,
                force: force
            )
        } catch {
            report(error)
        }
    }

    func stopSharingBusyTimes() async {
        guard case let .signedIn(context) = session, let busyPublisher else { return }
        do {
            try await busyPublisher.disableSharing(memberId: context.member.id)
        } catch {
            report(error)
        }
    }

    private func startBusyPublishing(spaceId: UUID) {
        let store = RepositoryBusyIntervalStore(repository: repositories.busyIntervals, spaceId: spaceId)
        busyPublisher = BusyPublisher(source: deviceCalendar ?? SystemDeviceCalendarSource(), store: store)
        corbieEventBusyPublisher = CorbieEventBusyPublisher(events: repositories.events, store: store)
        observeBusySources()
    }

    private func stopBusyPublishing() {
        busyPublisher = nil
        corbieEventBusyPublisher = nil
    }

    private func observeBusySources() {
        guard busySourceObservers.isEmpty else { return }
        let center = NotificationCenter.default
        busySourceObservers.append(
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in await self?.publishBusyTimes() }
            }
        )
        busySourceObservers.append(
            center.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in await self?.deviceCalendarChanged() }
            }
        )
    }

    private var mayPublishBusyTimes: Bool {
        #if DEBUG
        return isParkedForScreenshotMode == false
        #else
        return true
        #endif
    }

    private func deviceCalendarChanged() async {
        guard mayPublishBusyTimes, case let .signedIn(context) = session, let busyPublisher else { return }
        await busyPublisher.calendarStoreChanged(
            memberId: context.member.id,
            sharesBusyTimes: context.member.sharesBusyTimes
        )
    }

    func refreshEntitlement() async {
        guard let space else {
            await premiumGate.refreshWithoutSpace()
            return
        }
        await premiumGate.refresh(spaceId: space.id)
    }

    func storeAppleCredential(userIdentifier: String, identityToken: String?) throws {
        try identity.setAppleUserID(userIdentifier)
        guard let identityToken, identityToken.isEmpty == false else { return }
        try secrets.setString(identityToken, for: Self.appleIdentityTokenKey)
    }

    func exchangeSessionToken(authorizationCode: String?) async throws {
        guard let identityToken = try secrets.string(for: Self.appleIdentityTokenKey) else {
            throw CorbieError.auth("no apple identity token to exchange")
        }
        let token = try await sessionService.exchange(
            appleIdentityToken: identityToken,
            authorizationCode: authorizationCode
        )
        try secrets.setString(token.token, for: Self.sessionTokenKey)
        if let refreshToken = token.appleRefreshToken, refreshToken.isEmpty == false {
            try secrets.setString(refreshToken, for: Self.appleRefreshTokenKey)
        }
    }

    private func forgetAppleUserWithoutMember() {
        do {
            try identity.clear()
            AppEnvironment.log.notice("apple user id forgotten: no member or space on this phone uses it")
        } catch {
            AppEnvironment.log.error("forgetting the apple user id failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func signOut() {
        stopBusyPublishing()
        try? identity.clear()
        try? secrets.removeValue(for: Self.sessionTokenKey)
        try? secrets.removeValue(for: Self.appleIdentityTokenKey)
        try? secrets.removeValue(for: Self.appleRefreshTokenKey)
        session = .signedOut
        premiumGate.update(entitlements.stateWithoutSpace())
        Task { await remoteChanges.update(audience: nil) }
    }

    func apply(member: MemberDTO) {
        guard case let .signedIn(context) = session else { return }
        if context.member.id == member.id {
            session = .signedIn(SessionContext(space: context.space, member: member, partner: context.partner))
        } else if context.partner?.id == member.id {
            session = .signedIn(SessionContext(space: context.space, member: context.member, partner: member))
        }
        Task { await updateNotificationAudience() }
    }

    func apply(space: SpaceDTO) {
        guard case let .signedIn(context) = session, context.space.id == space.id else { return }
        session = .signedIn(SessionContext(space: space, member: context.member, partner: context.partner))
        Task { await updateNotificationAudience() }
    }

    func resyncNotificationBacklog() async {
        guard hasResyncedNotifications == false else { return }
        guard await notifications.authorizationStatus() == .authorized else { return }
        hasResyncedNotifications = true
        await NotificationBacklog.resync(self)
    }

    func updateNotificationAudience() async {
        await remoteChanges.update(audience: notificationAudience)
    }

    func replanPartnerProgressReminders(_ reminders: Set<PartnerProgressReminder>) async {
        guard let notificationAudience else { return }
        await remoteChanges.reminders.replan(reminders, for: notificationAudience)
    }

    private var notificationAudience: RemoteChangeNotifier.Audience? {
        guard case let .signedIn(context) = session else { return nil }
        return RemoteChangeNotifier.Audience(
            spaceId: context.space.id,
            memberId: context.member.id,
            partnerId: context.partner?.id,
            partnerName: partnerName,
            prefs: context.member.notificationPrefs,
            timeZone: context.space.anchorCalendarTimeZone
        )
    }

    func appleRefreshToken() -> String? {
        guard let token = try? secrets.string(for: Self.appleRefreshTokenKey), token.isEmpty == false else {
            return nil
        }
        return token
    }

    func wipeLocalState() async {
        stopBusyPublishing()
        await notifications.cancelEverything()
        await remoteChanges.stop()
        await remoteChanges.update(audience: nil)
        await remoteChanges.forgetJointAction()
        if let space { await entitlements.clearCache(spaceId: space.id) }
        try? identity.clear()
        try? secrets.removeValue(for: Self.sessionTokenKey)
        try? secrets.removeValue(for: Self.appleIdentityTokenKey)
        try? secrets.removeValue(for: Self.appleRefreshTokenKey)
        anonymousIdentity.reset()
        LiveInviteStore(defaults: defaults).forget()
        do {
            try StoreReset(stack: persistence.stack, defaults: defaults).wipe()
        } catch {
            report(error)
        }
        session = .signedOut
        premiumGate.update(entitlements.stateWithoutSpace())
        await remoteChanges.start()
    }

    private func reportStorageFailure() {
        if let failure = persistence.stack.loadFailure {
            AppEnvironment.log.error("store did not load: \(failure.localizedDescription, privacy: .public)")
            toasts.show(message: String(localized: "error.storage.message"))
            return
        }
        guard let storage, storage.isHealthy == false else { return }
        toasts.show(message: String(localized: "error.storage.message"))
    }

    func report(_ error: any Error) {
        toasts.show(message: error.localizedDescription)
    }
}

extension AppEnvironment {
    enum PartnerCheck: Equatable {
        case unchanged
        case reloaded
        case unreadable
    }
}

#if DEBUG
extension AppEnvironment {
    static func preview(
        persistence: PersistenceController = .preview,
        transport: (any HTTPTransport)? = nil
    ) -> AppEnvironment {
        AppEnvironment(
            persistence: persistence,
            secrets: InMemorySecretStore(),
            anonymousIdentity: .inMemory(),
            notificationClient: PreviewNotificationClient(),
            transport: transport
        )
    }

    static func previewSignedOut() -> AppEnvironment {
        let environment = AppEnvironment.preview()
        environment.session = .signedOut
        return environment
    }

    static func previewSignedIn(
        persistence: PersistenceController,
        space: SpaceDTO,
        member: MemberDTO,
        partner: MemberDTO?,
        transport: (any HTTPTransport)? = nil
    ) -> AppEnvironment {
        let environment = AppEnvironment.preview(persistence: persistence, transport: transport)
        environment.session = .signedIn(SessionContext(space: space, member: member, partner: partner))
        return environment
    }

    static func previewSignedIn(paired: Bool = true, transport: (any HTTPTransport)? = nil) -> AppEnvironment {
        let environment = AppEnvironment.preview(transport: transport)
        let member = MemberDTO(
            id: UUID(),
            displayName: PreviewNames.member,
            colorKey: MemberColorSlot.creatorDefault.rawValue,
            joinedAt: Date()
        )
        let partner = MemberDTO(
            id: UUID(),
            displayName: PreviewNames.partner,
            colorKey: MemberColorSlot.partnerDefault.rawValue,
            joinedAt: Date()
        )
        let space = SpaceDTO(
            id: UUID(),
            createdAt: Date(),
            creatorMemberId: member.id,
            subscriptionStatus: .active,
            subscriptionExpiresAt: Date().addingTimeInterval(365 * 24 * 3600),
            memberCount: paired ? 2 : 1
        )
        environment.session = .signedIn(
            SessionContext(space: space, member: member, partner: paired ? partner : nil)
        )
        return environment
    }
}
#endif
