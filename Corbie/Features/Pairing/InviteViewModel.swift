import CorbieCore
import Foundation
import Observation
import os

@MainActor
@Observable
final class InviteViewModel {
    enum Phase: Equatable {
        case idle
        case working
        case ready
        case failed
        case joined
    }

    static let joinedBeat: Duration = .milliseconds(1500)

    private(set) var phase: Phase = .idle
    private(set) var code: String?
    private(set) var expiresAt: Date?
    private(set) var failure: String?
    private(set) var joinedLine: String?

    private nonisolated static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "pairing")

    @ObservationIgnored private let environment: AppEnvironment
    @ObservationIgnored private let appState: AppState
    @ObservationIgnored private let spaceId: UUID
    @ObservationIgnored private let store: LiveInviteStore
    @ObservationIgnored private let minter: any InviteMinting
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let leave: () -> Void
    @ObservationIgnored private var sessionPartner: MemberDTO?
    @ObservationIgnored private var existingPartnerId: UUID?

    init(
        environment: AppEnvironment,
        appState: AppState,
        spaceId: UUID,
        store: LiveInviteStore? = nil,
        minter: (any InviteMinting)? = nil,
        now: @escaping () -> Date = Date.init,
        leave: @escaping () -> Void
    ) {
        self.environment = environment
        self.appState = appState
        self.spaceId = spaceId
        self.store = store ?? LiveInviteStore(defaults: environment.defaults)
        self.minter = minter ?? CloudInviteMinter(environment: environment)
        self.now = now
        self.leave = leave
    }

    static func joinedLine(name: String?) -> String {
        let name = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard name.isEmpty == false else { return String(localized: "pairing.invite.joined.unnamed") }
        return String(format: String(localized: "pairing.invite.joined"), name)
    }

    var shareMessage: String {
        guard let code else { return "" }
        return InviteLink.message(code: code)
    }

    func countdown(at date: Date) -> InviteCountdown? {
        guard let expiresAt else { return nil }
        return InviteCountdown(expiresAt: expiresAt, now: date)
    }

    func isShareable(at date: Date) -> Bool {
        guard phase == .ready else { return false }
        return countdown(at: date)?.isExpired == false
    }

    func appear(partner: MemberDTO?, reduceMotion: Bool) async {
        sessionPartner = partner
        guard phase != .working, phase != .joined else { return }
        if let live = store.live(for: spaceId, at: now()) {
            existingPartnerId = live.existingPartnerId
            if let arrivedPartner {
                await partnerJoined(arrivedPartner, reduceMotion: reduceMotion)
                return
            }
            show(live)
            InviteViewModel.log.notice("invite: showing the live code \(live.code, privacy: .public) again")
            return
        }
        await makeNewCode()
    }

    func apply(partner: MemberDTO?, reduceMotion: Bool) async {
        sessionPartner = partner
        guard phase != .idle, phase != .joined, let arrivedPartner else { return }
        await partnerJoined(arrivedPartner, reduceMotion: reduceMotion)
    }

    func makeNewCode() async {
        guard phase != .working, phase != .joined else { return }
        phase = .working
        code = nil
        expiresAt = nil
        failure = nil
        store.forget()
        existingPartnerId = partnerInSpace?.id
        do {
            let invite = try await minter.mint(spaceId: spaceId)
            guard phase == .working else { return }
            let live = LiveInvite(
                code: invite.code,
                expiresAt: invite.expiresAt,
                spaceId: spaceId,
                existingPartnerId: existingPartnerId
            )
            store.save(live)
            show(live)
            InviteViewModel.log.notice("invite: code \(invite.code, privacy: .public) is ready")
            environment.analytics.record(.inviteCreated)
        } catch {
            guard phase == .working else { return }
            let kind = PairingFailure.kind(for: error)
            phase = .failed
            failure = kind.message
            InviteViewModel.log.error(
                """
                invite failed as \(kind.rawValue, privacy: .public): \
                \((error as? LocalizedError)?.failureReason ?? error.localizedDescription, privacy: .public)
                """
            )
            environment.report(kind)
        }
    }

    private var partnerInSpace: MemberDTO? {
        guard let sessionPartner, sessionPartner.spaceId == spaceId else { return nil }
        return sessionPartner
    }

    private var arrivedPartner: MemberDTO? {
        guard let partnerInSpace, partnerInSpace.id != existingPartnerId else { return nil }
        return partnerInSpace
    }

    private func show(_ live: LiveInvite) {
        code = live.code
        expiresAt = live.expiresAt
        failure = nil
        phase = .ready
    }

    private func partnerJoined(_ partner: MemberDTO, reduceMotion: Bool) async {
        showJoined(partner)
        if reduceMotion == false {
            try? await Task.sleep(for: InviteViewModel.joinedBeat)
        }
        moveToToday()
    }

    private func showJoined(_ partner: MemberDTO) {
        phase = .joined
        code = nil
        expiresAt = nil
        failure = nil
        joinedLine = InviteViewModel.joinedLine(name: partner.displayName)
        store.forget()
        InviteViewModel.log.notice("invite: partner joined")
    }

    private func moveToToday() {
        appState.isUsHubPresented = false
        appState.selectedTab = .today
        leave()
    }
}
