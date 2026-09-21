import CorbieCore
import Foundation
import Observation
import os

@MainActor
@Observable
final class JoinViewModel {
    enum Phase: Equatable {
        case editing
        case working
        case joined
    }

    enum Block: Equatable {
        case paired
        case content

        var message: String {
            switch self {
            case .paired: return String(localized: "pairing.join.blocked.paired")
            case .content: return String(localized: "pairing.join.blocked.content")
            }
        }
    }

    static let spaceArrivalAttempts = 30
    static let spaceArrivalDelay = Duration.milliseconds(500)
    static let memberUploadTimeout = Duration.seconds(20)

    private nonisolated static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "pairing")

    var code = ""
    private(set) var phase: Phase = .editing
    private(set) var failure: String?
    private(set) var block: Block?

    @ObservationIgnored private let environment: AppEnvironment
    @ObservationIgnored private let appState: AppState
    @ObservationIgnored private let localSpace: SpaceDTO?
    @ObservationIgnored private let profile: ProfileDraft
    @ObservationIgnored private var redeemed: InviteShare?

    init(
        environment: AppEnvironment,
        appState: AppState,
        localSpace: SpaceDTO?,
        profile: ProfileDraft,
        code: String?
    ) {
        self.environment = environment
        self.appState = appState
        self.localSpace = localSpace
        self.profile = profile
        self.code = InviteCodeFormat.sanitize(code ?? "")
    }

    var isWorking: Bool { phase == .working }

    var canSubmit: Bool { InviteCodeFormat.isComplete(code) && phase == .editing && block == nil }

    func normalizeCode() {
        let sanitized = InviteCodeFormat.sanitize(code)
        if sanitized != code {
            code = sanitized
        }
        failure = nil
    }

    func submit() async {
        guard canSubmit else { return }
        phase = .working
        failure = nil
        do {
            try await join()
            phase = .joined
        } catch {
            phase = .editing
            guard block == nil else { return }
            let kind = PairingFailure.kind(for: error)
            failure = kind.message
            JoinViewModel.log.error(
                """
                join failed as \(kind.rawValue, privacy: .public): \
                \((error as? LocalizedError)?.failureReason ?? error.localizedDescription, privacy: .public)
                """
            )
        }
    }

    private func join() async throws {
        guard let appleUserID = environment.identity.currentAppleUserID else {
            throw CorbieError.auth("no apple user id is stored")
        }
        if let reason = await blockingReason() {
            block = reason
            throw CorbieError.invalidInput("local space cannot be replaced")
        }
        try await requireICloud()
        JoinViewModel.log.notice("join: redeeming the code on the server")
        let share = try await redeemedShare()
        guard let url = share.shareLink else {
            throw PairingFailure.shareMissing
        }
        JoinViewModel.log.notice("join: asking CloudKit for the share behind the link")
        let metadata = try await environment.sharing.fetchShareMetadata(from: url)
        guard await environment.sharing.isOwnShare(metadata) == false else {
            throw PairingFailure.ownAccount
        }
        JoinViewModel.log.notice("join: accepting the share")
        try await environment.sharing.acceptShare(metadata: metadata)
        JoinViewModel.log.notice("join: waiting for the space to arrive from iCloud")
        let joined = try await waitForJoinedSpace(id: share.spaceId)
        try await dropLocalSpace(joinedId: joined.id)
        let upload = environment.persistence.stack.watchUpload(of: .sharedStore)
        try await adoptMember(appleUserID: appleUserID, in: joined)
        try await carryTogetherSince(into: joined)
        environment.analytics.record(.inviteRedeemed)
        appState.selectedTab = .today
        await environment.reloadSession()
        let uploaded = await upload.finished(within: JoinViewModel.memberUploadTimeout)
        JoinViewModel.log.notice("join: member upload \(uploaded ? "finished" : "not confirmed", privacy: .public)")
        environment.toasts.show(
            message: uploaded
                ? String(localized: "pairing.join.connected")
                : String(localized: "pairing.join.connected.pending")
        )
    }

    private func requireICloud() async throws {
        switch await environment.sharing.iCloudAccount() {
        case .available, .unknown: return
        case .missing: throw PairingFailure.signedOutOfICloud
        case .busy: throw PairingFailure.iCloudBusy
        }
    }

    private func blockingReason() async -> Block? {
        guard let localSpace else { return nil }
        if localSpace.memberCount >= 2 { return .paired }
        let probe = SpaceContentProbe(repositories: environment.repositories)
        return await probe.holdsContent(spaceId: localSpace.id) ? .content : nil
    }

    private func redeemedShare() async throws -> InviteShare {
        if let redeemed { return redeemed }
        let share = try await environment.apiClient.redeemInvite(code: code)
        redeemed = share
        return share
    }

    private func waitForJoinedSpace(id: UUID) async throws -> SpaceDTO {
        for attempt in 0 ..< JoinViewModel.spaceArrivalAttempts {
            if let space = try? await environment.repositories.spaces.space(id: id) {
                return space
            }
            if attempt + 1 < JoinViewModel.spaceArrivalAttempts {
                try await Task.sleep(for: JoinViewModel.spaceArrivalDelay)
            }
        }
        throw PairingFailure.spaceLate
    }

    private func dropLocalSpace(joinedId: UUID) async throws {
        guard let localSpace, localSpace.id != joinedId else { return }
        do {
            try await environment.sharing.deleteSpace(space: localSpace.id)
        } catch {
            try await environment.repositories.spaces.delete(id: localSpace.id)
        }
    }

    private func adoptMember(appleUserID: String, in space: SpaceDTO) async throws {
        if let existing = try await environment.repositories.members.member(appleUserId: appleUserID),
           existing.spaceId != space.id {
            try await environment.repositories.members.delete(id: existing.id)
        }
        let saved = try await environment.repositories.members.upsertCurrentMember(
            appleUserId: appleUserID,
            spaceId: space.id,
            draft: profile.memberDraft,
            theme: environment.theme.activeTheme
        )
        environment.showColorShift(saved)
    }

    private func carryTogetherSince(into space: SpaceDTO) async throws {
        guard let togetherSince = profile.togetherSince, space.togetherSince == nil else { return }
        _ = try await environment.repositories.spaces.setTogetherSinceIfUnset(spaceId: space.id, togetherSince)
    }
}
