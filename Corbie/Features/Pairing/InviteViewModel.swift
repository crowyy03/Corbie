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
    }

    private(set) var phase: Phase = .idle
    private(set) var code: String?
    private(set) var expiresAt: Date?
    private(set) var failure: String?

    private nonisolated static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "pairing")

    @ObservationIgnored private let environment: AppEnvironment
    @ObservationIgnored private let spaceId: UUID
    @ObservationIgnored private let store: LiveInviteStore
    @ObservationIgnored private let minter: any InviteMinting
    @ObservationIgnored private let now: () -> Date

    init(
        environment: AppEnvironment,
        spaceId: UUID,
        store: LiveInviteStore = LiveInviteStore(),
        minter: (any InviteMinting)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.environment = environment
        self.spaceId = spaceId
        self.store = store
        self.minter = minter ?? CloudInviteMinter(environment: environment)
        self.now = now
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

    func appear() async {
        guard phase != .working else { return }
        if let live = store.live(for: spaceId, at: now()) {
            show(live)
            InviteViewModel.log.notice("invite: showing the live code \(live.code, privacy: .public) again")
            return
        }
        await makeNewCode()
    }

    func makeNewCode() async {
        guard phase != .working else { return }
        phase = .working
        code = nil
        expiresAt = nil
        failure = nil
        store.forget()
        do {
            let invite = try await minter.mint(spaceId: spaceId)
            let live = LiveInvite(code: invite.code, expiresAt: invite.expiresAt, spaceId: spaceId)
            store.save(live)
            show(live)
            InviteViewModel.log.notice("invite: code \(invite.code, privacy: .public) is ready")
            environment.analytics.record(.inviteCreated)
        } catch {
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

    private func show(_ live: LiveInvite) {
        code = live.code
        expiresAt = live.expiresAt
        failure = nil
        phase = .ready
    }
}
