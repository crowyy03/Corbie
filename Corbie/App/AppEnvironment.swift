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

    @ObservationIgnored let persistence: PersistenceController
    @ObservationIgnored let repositories: Repositories
    @ObservationIgnored let identity: MemberIdentity
    @ObservationIgnored let secrets: any SecretStore
    @ObservationIgnored let sharing: CloudKitSharing
    @ObservationIgnored let apiClient: APIClient
    @ObservationIgnored let analytics: Analytics
    @ObservationIgnored let entitlements: EntitlementService
    @ObservationIgnored let store: StoreService
    @ObservationIgnored let fx: FXService
    @ObservationIgnored let linkParser: LinkParser
    @ObservationIgnored let notifications: NotificationScheduler

    let premiumGate: PremiumGate
    let toasts: ToastCenter
    let theme: ThemeStore

    private(set) var session: Session = .loading

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
        sharing = CloudKitSharing(stack: persistence.stack)
        let tokenProvider: AppleTokenProvider = { [secrets] in
            if let token = try secrets.string(for: AppEnvironment.sessionTokenKey) { return token }
            return try secrets.string(for: AppEnvironment.appleIdentityTokenKey)
        }
        let client = APIClient(identity: anonymousIdentity, appleToken: tokenProvider)
        apiClient = client
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
        fx = FXService(client: client)
        linkParser = LinkParser(client: client)
        notifications = NotificationScheduler(client: notificationClient)
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
        await analytics.start()
        await notifications.registerCategories()
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
                  let space = try resolveSpace(memberId: member.id)
            else {
                session = .signedOut
                premiumGate.update(.readOnly)
                return
            }
            let partner = try await repositories.members.partner(of: member.id, spaceId: space.id)
            session = .signedIn(SessionContext(space: space, member: member, partner: partner))
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

    func signOut() {
        try? identity.clear()
        try? secrets.removeValue(for: Self.sessionTokenKey)
        try? secrets.removeValue(for: Self.appleIdentityTokenKey)
        session = .signedOut
        premiumGate.update(.readOnly)
    }

    func report(_ error: any Error) {
        toasts.show(message: error.localizedDescription)
    }

    private func resolveSpace(memberId: UUID) throws -> SpaceDTO? {
        guard let space = try sharing.currentSpace(in: persistence.viewContext, currentMemberId: memberId) else {
            return nil
        }
        return SpaceDTO(space)
    }
}

extension AppEnvironment {
    static func preview() -> AppEnvironment {
        AppEnvironment(
            persistence: .preview,
            secrets: InMemorySecretStore(),
            anonymousIdentity: .inMemory(),
            notificationClient: PreviewNotificationClient()
        )
    }
}
