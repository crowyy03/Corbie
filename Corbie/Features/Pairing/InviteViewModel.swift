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

    init(environment: AppEnvironment, spaceId: UUID) {
        self.environment = environment
        self.spaceId = spaceId
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

    func generate() async {
        guard phase != .working else { return }
        phase = .working
        code = nil
        expiresAt = nil
        failure = nil
        do {
            try await requireICloud()
            InviteViewModel.log.notice("invite: asking CloudKit for the share of \(self.spaceId, privacy: .public)")
            let share = try await environment.sharing.share(space: spaceId)
            guard let url = share.url else {
                throw PairingFailure.sharePending
            }
            InviteViewModel.log.notice("invite: share url is ready, asking the server for a code")
            let invite = try await environment.apiClient.createInvite(spaceId: spaceId, shareURL: url)
            code = invite.code
            expiresAt = invite.expiresAt
            phase = .ready
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

    private func requireICloud() async throws {
        switch await environment.sharing.iCloudAccount() {
        case .available, .unknown: return
        case .missing: throw PairingFailure.signedOutOfICloud
        case .busy: throw PairingFailure.iCloudBusy
        }
    }
}
