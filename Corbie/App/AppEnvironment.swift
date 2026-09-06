import CorbieCore
import CoreData
import Observation
import SwiftUI

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
    nonisolated static let appleAuthorizationCodeKey = "apple.authorization.code"
    nonisolated static let appleRefreshTokenKey = "apple.refresh.token"

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
    @ObservationIgnored let sessionService: SessionService

    private(set) var busyPublisher: BusyPublisher?
    let premiumGate: PremiumGate
    let usBadge: UsBadgeProvider
    let toasts: ToastCenter
    let theme: ThemeStore

    private(set) var session: Session = .loading

    @ObservationIgnored private var hasResyncedNotifications = false

    init(
        persistence: PersistenceController = .shared,
        secrets: any SecretStore = KeychainStore(),
        anonymousIdentity: AnonymousIdentity = .shared,
        notificationClient: any NotificationCenterClient = SystemNotificationCenterClient(),
        store: StoreService = .shared
    ) {
        self.persistence = persistence
        repositories = persistence.repositories
        self.secrets = secrets
        identity = MemberIdentity(store: secrets)
        self.anonymousIdentity = anonymousIdentity
        sharing = CloudKitSharing(stack: persistence.stack)
        let tokenProvider: AppleTokenProvider = { [secrets] in
            if let token = try secrets.string(for: AppEnvironment.sessionTokenKey) { return token }
            return try secrets.string(for: AppEnvironment.appleIdentityTokenKey)
        }
        let client = APIClient(identity: anonymousIdentity, appleToken: tokenProvider)
        apiClient = client
        sessionService = SessionService(configuration: client.configuration)
        analytics = Analytics(client: client, identity: anonymousIdentity)
        self.store = store
        let entitlementService = EntitlementService(
            client: client,
            spaces: persistence.repositories.spaces,
            store: secrets,
            local: store
        )
        entitlements = entitlementService
        premiumGate = PremiumGate(analytics: analytics, entitlements: entitlementService)
        usBadge = UsBadgeProvider(repositories: repositories)
        fx = FXService(client: client)
        linkParser = LinkParser(client: client)
        let scheduler = NotificationScheduler(client: notificationClient)
        notifications = scheduler
        remoteChanges = RemoteChangeNotifier(stack: persistence.stack, scheduler: scheduler)
        toasts = ToastCenter()
        theme = ThemeStore()
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

    func bootstrap() async {
        do {
            try persistence.stack.initializeCloudKitSchemaIfRequested()
        } catch {
            report(error)
        }
        IntentPersistence.shared.use(controller: persistence, identity: identity)
        WidgetReloader.shared.start()
        usBadge.observeReloads()
        await analytics.start()
        await notifications.registerCategories()
        await remoteChanges.start()
        await reloadSession()
    }

    func reloadSession() async {
        guard let appleUserID = identity.currentAppleUserID else {
            session = .signedOut
            premiumGate.update(.readOnly)
            return
        }
        do {
            guard let member = try await repositories.members.member(appleUserId: appleUserID),
                  let space = try await repositories.spaces.currentSpace(memberId: member.id)
            else {
                session = .signedOut
                premiumGate.update(.readOnly)
                return
            }
            let partner = try await repositories.members.partner(of: member.id, spaceId: space.id)
            session = .signedIn(SessionContext(space: space, member: member, partner: partner))
            busyPublisher = BusyPublisher(
                source: SystemDeviceCalendarSource(),
                store: RepositoryBusyIntervalStore(repository: repositories.busyIntervals, spaceId: space.id)
            )
            await updateNotificationAudience()
            await resyncNotificationBacklog()
            premiumGate.update(await entitlements.cachedState(spaceId: space.id, trialEndsAt: space.trialEndsAt))
            try? await repositories.members.touchLastSeen(memberId: member.id)
            Task { await premiumGate.refresh(spaceId: space.id) }
        } catch {
            session = .signedOut
            report(error)
        }
    }

    func refreshEntitlement() async {
        guard let space else { return }
        await premiumGate.refresh(spaceId: space.id)
    }

    func storeAppleCredential(
        userIdentifier: String,
        identityToken: String?,
        authorizationCode: String? = nil
    ) throws {
        try identity.setAppleUserID(userIdentifier)
        storeAppleRevocationSecret(authorizationCode: authorizationCode)
        guard let identityToken, identityToken.isEmpty == false else { return }
        try secrets.setString(identityToken, for: Self.appleIdentityTokenKey)
    }

    func exchangeSessionToken() async throws {
        guard let identityToken = try secrets.string(for: Self.appleIdentityTokenKey) else {
            throw CorbieError.auth("no apple identity token to exchange")
        }
        let token = try await sessionService.exchange(appleIdentityToken: identityToken)
        try secrets.setString(token.token, for: Self.sessionTokenKey)
    }

    func signOut() {
        try? identity.clear()
        try? secrets.removeValue(for: Self.sessionTokenKey)
        try? secrets.removeValue(for: Self.appleIdentityTokenKey)
        try? secrets.removeValue(for: Self.appleAuthorizationCodeKey)
        try? secrets.removeValue(for: Self.appleRefreshTokenKey)
        session = .signedOut
        premiumGate.update(.readOnly)
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
    }

    func resyncNotificationBacklog() async {
        guard hasResyncedNotifications == false else { return }
        guard await notifications.authorizationStatus() == .authorized else { return }
        hasResyncedNotifications = true
        await NotificationBacklog.resync(self)
    }

    func updateNotificationAudience() async {
        guard case let .signedIn(context) = session else {
            await remoteChanges.update(audience: nil)
            return
        }
        await remoteChanges.update(
            audience: RemoteChangeNotifier.Audience(
                spaceId: context.space.id,
                memberId: context.member.id,
                partnerId: context.partner?.id,
                partnerName: partnerName,
                prefs: context.member.notificationPrefs
            )
        )
    }

    func storeAppleRevocationSecret(authorizationCode: String?, refreshToken: String? = nil) {
        if let authorizationCode, authorizationCode.isEmpty == false {
            try? secrets.setString(authorizationCode, for: Self.appleAuthorizationCodeKey)
        }
        if let refreshToken, refreshToken.isEmpty == false {
            try? secrets.setString(refreshToken, for: Self.appleRefreshTokenKey)
        }
    }

    func appleRevocationSecret() -> (authorizationCode: String?, refreshToken: String?) {
        (
            try? secrets.string(for: Self.appleAuthorizationCodeKey),
            try? secrets.string(for: Self.appleRefreshTokenKey)
        )
    }

    func wipeLocalState() async {
        await notifications.cancelEverything()
        await remoteChanges.stop()
        await remoteChanges.update(audience: nil)
        await remoteChanges.forgetJointAction()
        if let space { await entitlements.clearCache(spaceId: space.id) }
        try? identity.clear()
        try? secrets.removeValue(for: Self.sessionTokenKey)
        try? secrets.removeValue(for: Self.appleIdentityTokenKey)
        try? secrets.removeValue(for: Self.appleAuthorizationCodeKey)
        try? secrets.removeValue(for: Self.appleRefreshTokenKey)
        anonymousIdentity.reset()
        do {
            try StoreReset(stack: persistence.stack).wipe()
        } catch {
            report(error)
        }
        session = .signedOut
        premiumGate.update(.readOnly)
        await remoteChanges.start()
    }

    func report(_ error: any Error) {
        toasts.show(message: error.localizedDescription)
    }

}

#if DEBUG
extension AppEnvironment {
    static func preview() -> AppEnvironment {
        AppEnvironment(
            persistence: .preview,
            secrets: InMemorySecretStore(),
            anonymousIdentity: .inMemory(),
            notificationClient: PreviewNotificationClient()
        )
    }

    static func previewSignedOut() -> AppEnvironment {
        let environment = AppEnvironment.preview()
        environment.session = .signedOut
        return environment
    }

    static func previewSignedIn(paired: Bool = true) -> AppEnvironment {
        let environment = AppEnvironment.preview()
        let member = MemberDTO(
            id: UUID(),
            displayName: PreviewNames.member,
            colorKey: MemberColorKey.defaultA.rawValue,
            joinedAt: Date()
        )
        let partner = MemberDTO(
            id: UUID(),
            displayName: PreviewNames.partner,
            colorKey: MemberColorKey.defaultB.rawValue,
            joinedAt: Date()
        )
        let space = SpaceDTO(
            id: UUID(),
            createdAt: Date(),
            creatorMemberId: member.id,
            trialEndsAt: Date().addingTimeInterval(7 * 24 * 3600),
            memberCount: paired ? 2 : 1
        )
        environment.session = .signedIn(
            SessionContext(space: space, member: member, partner: paired ? partner : nil)
        )
        return environment
    }
}
#endif
