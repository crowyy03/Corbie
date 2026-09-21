import CorbieCore
import Foundation

@MainActor
protocol InviteMinting {
    func mint(spaceId: UUID) async throws -> InviteCode
}

@MainActor
struct CloudInviteMinter: InviteMinting {
    let environment: AppEnvironment

    func mint(spaceId: UUID) async throws -> InviteCode {
        try await requireICloud()
        let share = try await PairingStepLog.measure("invite: create the share") {
            try await environment.sharing.share(space: spaceId)
        }
        guard let url = share.url else {
            throw PairingFailure.sharePending
        }
        return try await PairingStepLog.measure("invite: POST /invite") {
            try await environment.apiClient.createInvite(spaceId: spaceId, shareURL: url)
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
