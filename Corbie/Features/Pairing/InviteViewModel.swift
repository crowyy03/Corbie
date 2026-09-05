import CorbieCore
import Foundation
import Observation

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
        do {
            let share = try await environment.sharing.share(space: spaceId)
            guard let url = share.url else {
                throw CorbieError.cloudKit("the share has no url yet")
            }
            let invite = try await environment.apiClient.createInvite(spaceId: spaceId, shareURL: url)
            code = invite.code
            expiresAt = invite.expiresAt
            phase = .ready
            environment.analytics.record(.inviteCreated)
        } catch {
            phase = .failed
            environment.report(error)
        }
    }
}
